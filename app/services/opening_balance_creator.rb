class OpeningBalanceCreator
  include AccountingConstants

  Result = Struct.new(:success?, :data, :errors, keyword_init: true)

  # Creates opening balance entries for a fiscal year
  # Supports two modes:
  # 1. Manual entry - User provides balance sheet data
  # 2. Carryforward - Copy from previous year's closing balance
  #
  # @param fiscal_year [FiscalYear] The fiscal year to create opening balance for
  # @param balance_data [Hash] Balance sheet data with aktiva and passiva sections
  # @param source [String] 'manual' or 'carryforward'
  def initialize(fiscal_year:, balance_data:, source:)
    @fiscal_year = fiscal_year
    @balance_data = balance_data
    @source = source
    @company = fiscal_year.company
    @errors = []
  end

  def call
    ActiveRecord::Base.transaction do
      # 1. Validate balance sheet balances (Aktiva = Passiva)
      return failure("Balance sheet data is required") unless @balance_data.present?

      unless validate_balance_sheet
        return failure("Balance sheet does not balance: #{@errors.join(', ')}")
      end

      # 2. Create BalanceSheet record
      balance_sheet = create_balance_sheet
      return failure("Failed to create balance sheet: #{balance_sheet.errors.full_messages.join(', ')}") unless balance_sheet.persisted?

      # 3. Generate EBK journal entries using account 9000
      journal_entry = create_ebk_journal_entry
      return failure("Failed to create journal entry: #{journal_entry.errors.full_messages.join(', ')}") unless journal_entry.persisted?

      # 4. Post journal entries
      journal_entry.post!

      # 5. Update fiscal_year.opening_balance_posted_at
      @fiscal_year.update!(opening_balance_posted_at: Time.current)

      # 6. Post the balance sheet
      balance_sheet.post!

      success(balance_sheet: balance_sheet, journal_entry: journal_entry)
    rescue StandardError => e
      failure("Error creating opening balance: #{e.message} #{e.backtrace.join('\n')}")
    end
  end

  private

  def validate_balance_sheet
    # Check for required structure
    unless @balance_data[:aktiva].present? && @balance_data[:passiva].present?
      @errors << "Invalid balance sheet structure: missing aktiva or passiva sections"
      return false
    end

    aktiva_total = calculate_total(@balance_data[:aktiva])
    passiva_total = calculate_total(@balance_data[:passiva])

    if (aktiva_total - passiva_total).abs > 0.01
      @errors << "Aktiva (#{aktiva_total}) does not equal Passiva (#{passiva_total})"
      return false
    end

    true
  end

  def calculate_total(section)
    return 0 unless section.is_a?(Hash)

    total = 0
    section.each_value do |accounts|
      next unless accounts.is_a?(Array)

      accounts.each do |account|
        total += account[:balance].to_f if account[:balance]
      end
    end
    total
  end

  def create_balance_sheet
    BalanceSheet.create!(
      fiscal_year: @fiscal_year,
      sheet_type: "opening",
      source: @source,
      balance_date: @fiscal_year.start_date,
      data: @balance_data,
      metadata: {
        created_by: "OpeningBalanceCreator",
        created_at: Time.current
      }
    )
  end

  def create_ebk_journal_entry
    # Create journal entry with opening type
    journal_entry = JournalEntry.new(
      company: @company,
      fiscal_year: @fiscal_year,
      booking_date: @fiscal_year.start_date,
      description: "Eröffnungsbilanz #{@fiscal_year.year}",
      entry_type: "opening"
    )

    # Get or create the EBK account (9000)
    ebk_account = find_or_create_ebk_account

    # Create line items for all balance sheet accounts
    create_line_items_for_accounts(journal_entry, ebk_account)

    journal_entry.save!
    journal_entry
  end

  def find_or_create_ebk_account
    # First try to find existing account
    account = @company.accounts.find_by(code: CLOSING_ACCOUNTS[:ebk_sbk])
    return account if account

    # If not found, create from template
    unless @company.chart_of_accounts.present?
      raise "Cannot create EBK account: company has no chart of accounts"
    end

    template = @company.chart_of_accounts.account_templates.find_by(code: CLOSING_ACCOUNTS[:ebk_sbk])
    unless template
      raise "Cannot create EBK account: account template #{CLOSING_ACCOUNTS[:ebk_sbk]} not found in chart of accounts"
    end

    account = template.add_to_company(@company)
    unless account
      raise "Failed to create EBK account #{CLOSING_ACCOUNTS[:ebk_sbk]} from template"
    end

    account
  end

  def create_line_items_for_accounts(journal_entry, ebk_account)
    ebk_total_debit = 0
    ebk_total_credit = 0

    # Process Aktiva (Assets) - Debit the asset accounts, Credit EBK
    process_section(@balance_data[:aktiva], journal_entry) do |account_data|
      balance = account_data[:balance].to_f
      next if balance.abs < 0.01

      account = find_or_create_account(account_data[:account_code])
      next unless account

      # Debit asset account
      journal_entry.line_items.build(
        account: account,
        amount: balance,
        direction: "debit"
      )

      # Track credit to EBK
      ebk_total_credit += balance
    end

    # Process Passiva (Liabilities & Equity) - Credit the accounts, Debit EBK
    process_section(@balance_data[:passiva], journal_entry) do |account_data|
      balance = account_data[:balance].to_f
      next if balance.abs < 0.01

      account = find_or_create_account(account_data[:account_code])
      next unless account

      # Credit liability/equity account
      journal_entry.line_items.build(
        account: account,
        amount: balance,
        direction: "credit"
      )

      # Track debit to EBK
      ebk_total_debit += balance
    end

    # Create balancing EBK line items
    if ebk_total_credit > 0.01
      journal_entry.line_items.build(
        account: ebk_account,
        amount: ebk_total_credit,
        direction: "credit"
      )
    end

    if ebk_total_debit > 0.01
      journal_entry.line_items.build(
        account: ebk_account,
        amount: ebk_total_debit,
        direction: "debit"
      )
    end
  end

  def process_section(section, journal_entry, &block)
    return unless section.is_a?(Hash)

    section.each_value do |accounts|
      next unless accounts.is_a?(Array)

      accounts.each do |account_data|
        yield(account_data)
      end
    end
  end

  def find_or_create_account(code)
    # First try to find existing account
    account = @company.accounts.find_by(code: code)
    return account if account

    # If not found, create from template
    unless @company.chart_of_accounts.present?
      raise "Cannot create account #{code}: company has no chart of accounts"
    end

    template = @company.chart_of_accounts.account_templates.find_by(code: code)
    unless template
      raise "Cannot create account: account template #{code} not found in chart of accounts"
    end

    account = template.add_to_company(@company)
    unless account
      raise "Failed to create account #{code} from template"
    end

    account
  end

  def success(data)
    Result.new(success?: true, data: data, errors: [])
  end

  def failure(message)
    Result.new(success?: false, data: nil, errors: [ message ])
  end
end
