class FiscalYearClosingService
  include AccountingConstants

  Result = Struct.new(:success?, :data, :errors, keyword_init: true)

  # Closes a fiscal year and generates SBK (Schlussbilanzkonto) entries
  #
  # @param fiscal_year [FiscalYear] The fiscal year to close
  # @param user [User] The user performing the closing (optional, for audit trail)
  # @param create_next_year_opening [Boolean] Whether to create opening balance for next year
  def initialize(fiscal_year:, user: nil, create_next_year_opening: true)
    @fiscal_year = fiscal_year
    @user = user
    @create_next_year_opening = create_next_year_opening
    @company = fiscal_year.company
    @errors = []
  end

  def call
    return failure("Fiscal year is already closed") if @fiscal_year.closed?
    return failure("Opening balance must be posted before closing") unless @fiscal_year.opening_balance_posted?

    ActiveRecord::Base.transaction do
      # 1. Calculate final balance sheet using BalanceSheetService
      balance_sheet_result = BalanceSheetService.new(company: @company, fiscal_year: @fiscal_year).call

      return failure("Failed to calculate balance sheet: #{balance_sheet_result.errors.join(', ')}") unless balance_sheet_result.success?

      balance_sheet_data = balance_sheet_result.data

      # 2. Validate balance sheet balances
      unless balance_sheet_data[:balanced]
        return failure("Balance sheet does not balance (Aktiva: #{balance_sheet_data[:aktiva][:total]}, Passiva: #{balance_sheet_data[:passiva][:total]})")
      end

      # 3. Create SBK journal entries using account 9000
      journal_entry = create_sbk_journal_entry(balance_sheet_data)
      return failure("Failed to create closing journal entry: #{journal_entry.errors.full_messages.join(', ')}") unless journal_entry.persisted?

      # 4. Store balance sheet in balance_sheets table
      stored_balance_sheet = store_balance_sheet(balance_sheet_data)
      return failure("Failed to store balance sheet: #{stored_balance_sheet.errors.full_messages.join(', ')}") unless stored_balance_sheet.persisted?

      # 5. Mark fiscal_year as closed
      @fiscal_year.update!(
        closing_balance_posted_at: Time.current,
        closed: true,
        closed_at: Time.current
      )

      # 6. Post the balance sheet and journal entry
      journal_entry.post!
      stored_balance_sheet.post!

      # 7. Optionally create opening entries for next year
      next_year_result = nil
      if @create_next_year_opening
        next_year_result = create_next_year_opening_balance(balance_sheet_data)
      end

      success(
        balance_sheet: stored_balance_sheet,
        journal_entry: journal_entry,
        next_year: next_year_result
      )
    rescue StandardError => e
      failure("Error closing fiscal year: #{e.message}")
    end
  end

  private

  # Helper method to recursively extract all accounts from nested sections
  def extract_accounts_from_sections(sections_hash)
    return [] unless sections_hash

    accounts = []
    sections_hash.each_value do |section|
      # Add accounts from this section
      accounts.concat(section[:accounts]) if section[:accounts]

      # Recursively add accounts from children
      if section[:children] && section[:children].any?
        section[:children].each do |child_section|
          accounts.concat(extract_accounts_from_section(child_section))
        end
      end
    end
    accounts
  end

  # Helper to extract accounts from a single section (recursive)
  def extract_accounts_from_section(section)
    accounts = section[:accounts] || []
    if section[:children] && section[:children].any?
      section[:children].each do |child_section|
        accounts.concat(extract_accounts_from_section(child_section))
      end
    end
    accounts
  end

  def create_sbk_journal_entry(balance_sheet_data)
    # Create journal entry with closing type
    journal_entry = JournalEntry.new(
      company: @company,
      fiscal_year: @fiscal_year,
      booking_date: @fiscal_year.end_date,
      description: "Schlussbilanz #{@fiscal_year.year}",
      entry_type: "closing"
    )

    # Get or create the SBK account (9000)
    sbk_account = find_or_create_sbk_account

    # Create line items for closing entries
    # SBK is the reverse of EBK:
    # - Assets: Credit the asset accounts, Debit SBK
    # - Liabilities/Equity: Debit the accounts, Credit SBK
    create_closing_line_items(journal_entry, sbk_account, balance_sheet_data)

    journal_entry.save!
    journal_entry
  end

  def find_or_create_sbk_account
    # First try to find existing account
    account = @company.accounts.find_by(code: CLOSING_ACCOUNTS[:ebk_sbk])
    return account if account

    # If not found, create from template
    return nil unless @company.chart_of_accounts.present?

    template = @company.chart_of_accounts.account_templates.find_by(code: CLOSING_ACCOUNTS[:ebk_sbk])
    return nil unless template

    template.add_to_company(@company)
  end

  def create_closing_line_items(journal_entry, sbk_account, balance_sheet_data)
    sbk_total_debit = 0
    sbk_total_credit = 0

    # Extract all accounts from nested sections
    aktiva_accounts = extract_accounts_from_sections(balance_sheet_data[:aktiva][:sections])
    passiva_accounts = extract_accounts_from_sections(balance_sheet_data[:passiva][:sections])

    # Process Aktiva (Assets) - Credit the asset accounts (closing them out), Debit SBK
    aktiva_accounts.each do |account_data|
      balance = account_data[:balance].to_f
      next if balance.abs < 0.01

      account = @company.accounts.find_by(code: account_data[:account_code])
      next unless account

      # Credit asset account (closing it)
      journal_entry.line_items.build(
        account: account,
        amount: balance,
        direction: "credit"
      )

      # Track debit to SBK
      sbk_total_debit += balance
    end

    # Process Passiva (Liabilities & Equity) - Debit the accounts (closing them out), Credit SBK
    passiva_accounts.each do |account_data|
      balance = account_data[:balance].to_f
      next if balance.abs < 0.01

      # Skip the pseudo net_income account (it's already reflected in equity accounts)
      next if account_data[:account_code] == "net_income"

      account = @company.accounts.find_by(code: account_data[:account_code])
      next unless account

      # Debit liability/equity account (closing it)
      journal_entry.line_items.build(
        account: account,
        amount: balance,
        direction: "debit"
      )

      # Track credit to SBK
      sbk_total_credit += balance
    end

    # Create balancing SBK line items
    if sbk_total_debit > 0.01
      journal_entry.line_items.build(
        account: sbk_account,
        amount: sbk_total_debit,
        direction: "debit"
      )
    end

    if sbk_total_credit > 0.01
      journal_entry.line_items.build(
        account: sbk_account,
        amount: sbk_total_credit,
        direction: "credit"
      )
    end
  end

  def store_balance_sheet(balance_sheet_data)
    BalanceSheet.create!(
      fiscal_year: @fiscal_year,
      sheet_type: "closing",
      source: "calculated",
      balance_date: @fiscal_year.end_date,
      data: balance_sheet_data,
      metadata: {
        created_by: @user&.email || "FiscalYearClosingService",
        created_at: Time.current,
        aktiva_total: balance_sheet_data[:aktiva][:total],
        passiva_total: balance_sheet_data[:passiva][:total],
        balanced: balance_sheet_data[:balanced]
      }
    )
  end

  def create_next_year_opening_balance(balance_sheet_data)
    # Find or create next fiscal year
    next_year = @company.fiscal_years.find_by(year: @fiscal_year.year + 1)

    unless next_year
      start_date, end_date = @company.default_start_end_date(@fiscal_year.year + 1)
      next_year = @company.fiscal_years.create!(
        year: @fiscal_year.year + 1,
        start_date: start_date,
        end_date: end_date,
        closed: false
      )
    end

    # Don't create opening balance if it already exists
    if next_year.opening_balance_posted?
      return { skipped: true, reason: "Opening balance already exists for #{next_year.year}" }
    end

    # Create opening balance using carryforward
    creator = OpeningBalanceCreator.new(
      fiscal_year: next_year,
      balance_data: balance_sheet_data,
      source: "carryforward"
    )

    result = creator.call

    if result.success?
      { created: true, fiscal_year_id: next_year.id, year: next_year.year }
    else
      { created: false, errors: result.errors }
    end
  end

  def success(data)
    Result.new(success?: true, data: data, errors: [])
  end

  def failure(message)
    Result.new(success?: false, data: nil, errors: [ message ])
  end
end
