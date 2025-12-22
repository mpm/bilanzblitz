# Service to calculate GuV (Gewinn- und Verlustrechnung / Profit & Loss Statement)
# using the Gesamtkostenverfahren (Total Cost Method) according to § 275 Abs. 2 HGB
class GuVService
  Result = Struct.new(:success?, :data, :errors, keyword_init: true)

  def initialize(company:, fiscal_year:, only_posted: true)
    @company = company
    @fiscal_year = fiscal_year
    @only_posted = only_posted
    @only_posted = false if !Rails.env.test? && !FeatureFlag.only_posted_enabled?
  end

  def call
    return failure("Company is required") unless @company
    return failure("Fiscal year is required") unless @fiscal_year

    account_balances = calculate_account_balances
    guv_structure = build_guv_structure(account_balances)

    Result.new(success?: true, data: guv_structure, errors: [])
  rescue StandardError => e
    Result.new(success?: false, data: nil, errors: [ e.message ])
  end

  private

  def calculate_account_balances
    # Query all accounts with their aggregated debit/credit amounts
    # Only include posted journal entries (GoBD compliance) when only_posted is true
    # Exclude closing entries (they close out accounts, not part of GuV)
    # Exclude 9xxx accounts (closing accounts, not part of GuV)
    query = @company.accounts
      .joins(line_items: :journal_entry)
      .where(journal_entries: { fiscal_year_id: @fiscal_year.id })

    query = query.where.not(journal_entries: { posted_at: nil }) if @only_posted

    results = query.where.not(journal_entries: { entry_type: "closing" })
      .where.not("accounts.code LIKE '9%'")
      .select(
        "accounts.id",
        "accounts.code",
        "accounts.name",
        "accounts.account_type",
        "SUM(CASE WHEN line_items.direction = 'debit' THEN line_items.amount ELSE 0 END) as total_debit",
        "SUM(CASE WHEN line_items.direction = 'credit' THEN line_items.amount ELSE 0 END) as total_credit"
      )
      .group("accounts.id", "accounts.code", "accounts.name", "accounts.account_type")

    # Calculate net balance for each account
    results.map do |account|
      balance = calculate_account_balance(
        account.account_type,
        account.total_debit.to_f,
        account.total_credit.to_f
      )

      {
        id: account.id,
        code: account.code,
        name: account.name,
        type: account.account_type,
        balance: balance
      }
    end.reject { |a| a[:balance].abs < 0.01 } # Filter near-zero balances
  end

  def calculate_account_balance(account_type, total_debit, total_credit)
    case account_type
    when "asset", "expense"
      # Debit balance accounts
      total_debit - total_credit
    when "liability", "equity", "revenue"
      # Credit balance accounts
      total_credit - total_debit
    else
      0
    end
  end

  def build_guv_structure(account_balances)
    sections = []

    # Iterate through all GuV sections from AccountMap in correct order (§ 275 Abs. 2 HGB)
    AccountMap.guv_sections_ordered.each do |section_id, section_data|
      # Skip sections without accounts (parent sections or calculated fields)
      next if section_data[:accounts].empty?

      # Get accounts for this section
      section_accounts = AccountMap.find_accounts(account_balances, section_id)

      # Determine display type based on section type
      display_type = section_data[:section_type] == :revenue ? :positive : :negative

      # Build section
      sections << build_section(
        key: section_id,
        label: section_data[:title],
        accounts: section_accounts,
        display_type: display_type
      )
    end

    # Calculate net income (sum of all section subtotals)
    net_income = sections.sum { |s| s[:subtotal] }

    {
      sections: sections,
      net_income: net_income.round(2),
      net_income_label: net_income >= 0 ? "Jahresüberschuss" : "Jahresfehlbetrag"
    }
  end

  def build_section(key:, label:, accounts:, display_type:)
    # Calculate subtotal based on display type
    # For revenue (positive display): sum balances as-is
    # For expenses (negative display): negate balances (they're positive debit balances, but we want negative for GuV)
    subtotal = if display_type == :positive
      accounts.sum { |a| a[:balance] }
    else
      -accounts.sum { |a| a[:balance].abs }
    end

    {
      key: key,
      label: label,
      accounts: format_accounts(accounts),
      subtotal: subtotal.round(2),
      display_type: display_type
    }
  end

  def format_accounts(accounts)
    accounts.map do |account|
      {
        code: account[:code],
        name: account[:name],
        balance: account[:balance].round(2)
      }
    end
  end

  def failure(message)
    Result.new(success?: false, data: nil, errors: [ message ])
  end
end
