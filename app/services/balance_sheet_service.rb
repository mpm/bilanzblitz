class BalanceSheetService
  Result = Struct.new(:success?, :data, :errors, keyword_init: true)

  def initialize(company:, fiscal_year:)
    @company = company
    @fiscal_year = fiscal_year
  end

  def call
    return failure("Company is required") unless @company
    return failure("Fiscal year is required") unless @fiscal_year

    # If fiscal year is closed, try to load stored balance sheet
    if @fiscal_year.closed?
      stored_sheet = load_stored_balance_sheet
      return Result.new(success?: true, data: stored_sheet, errors: []) if stored_sheet
    end

    # Otherwise calculate on-the-fly
    account_balances = calculate_account_balances
    grouped_accounts = group_by_balance_sheet_sections(account_balances)
    net_income = calculate_net_income(account_balances)

    # Build balance sheet structure
    data = build_balance_sheet_data(grouped_accounts, net_income)

    Result.new(success?: true, data: data, errors: [])
  rescue StandardError => e
    Result.new(success?: false, data: nil, errors: [ e.message ])
  end

  private

  def calculate_account_balances
    # Query all accounts with their aggregated debit/credit amounts
    # Only include posted journal entries (GoBD compliance)
    # Exclude closing entries (they close out accounts, not part of ongoing balance)
    results = @company.accounts
      .joins(line_items: :journal_entry)
      .where(journal_entries: { fiscal_year_id: @fiscal_year.id })
      .where.not(journal_entries: { posted_at: nil })
      .where.not(journal_entries: { entry_type: "closing" })
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
        code: account.code,
        name: account.name,
        type: account.account_type,
        balance: balance
      }
    end.reject { |a| a[:balance].abs < 0.01 || a[:code].start_with?("9") } # Filter near-zero balances and 9000-series closing accounts
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

  def group_by_balance_sheet_sections(account_balances)
    {
      anlagevermoegen: [], # Fixed assets (0xxx)
      umlaufvermoegen: [], # Current assets (1xxx)
      eigenkapital: [],    # Equity (2xxx)
      fremdkapital: [],    # Liabilities (3xxx)
      revenue: [],         # Revenue (4xxx) - for P&L calculation
      expenses: []         # Expenses (5xxx, 6xxx, 7xxx) - for P&L calculation
    }.tap do |groups|
      account_balances.each do |account|
        c = account[:code]

        if c == "0800"
          groups[:eigenkapital] << account
        else
          code_prefix = account[:code][0] # First digit of account code

          case code_prefix
          when "0"
            groups[:anlagevermoegen] << account
          when "1"
            groups[:umlaufvermoegen] << account
          when "2"
            groups[:eigenkapital] << account
          when "3"
            groups[:fremdkapital] << account
          when "4"
            groups[:revenue] << account
          when "5", "6", "7"
            groups[:expenses] << account
          end
        end
      end
    end
  end

  def calculate_net_income(account_balances)
    # Revenue (4xxx) - Expenses (5xxx, 6xxx, 7xxx)
    revenue = account_balances
      .select { |a| a[:code].start_with?("4") }
      .sum { |a| a[:balance] }

    expenses = account_balances
      .select { |a| a[:code].match?(/^[567]/) }
      .sum { |a| a[:balance] }

    revenue - expenses
  end

  def build_balance_sheet_data(grouped_accounts, net_income)
    # Build Aktiva (Assets) section
    aktiva_accounts = grouped_accounts[:anlagevermoegen] + grouped_accounts[:umlaufvermoegen]
    aktiva_total = aktiva_accounts.sum { |a| a[:balance] }

    # Build Passiva (Liabilities & Equity) section
    # Add net income to equity
    eigenkapital_accounts = grouped_accounts[:eigenkapital].dup
    eigenkapital_accounts << {
      code: "net_income",
      name: net_income >= 0 ? "Jahresüberschuss" : "Jahresfehlbetrag",
      type: "equity",
      balance: net_income
    }

    passiva_accounts = eigenkapital_accounts + grouped_accounts[:fremdkapital]
    passiva_total = passiva_accounts.sum { |a| a[:balance] }

    # Check if balance sheet balances
    balanced = (aktiva_total - passiva_total).abs < 0.01

    {
      fiscal_year: {
        id: @fiscal_year.id,
        year: @fiscal_year.year,
        start_date: @fiscal_year.start_date,
        end_date: @fiscal_year.end_date,
        closed: @fiscal_year.closed
      },
      aktiva: {
        anlagevermoegen: format_accounts(grouped_accounts[:anlagevermoegen]),
        umlaufvermoegen: format_accounts(grouped_accounts[:umlaufvermoegen]),
        total: aktiva_total.round(2)
      },
      passiva: {
        eigenkapital: format_accounts(eigenkapital_accounts),
        fremdkapital: format_accounts(grouped_accounts[:fremdkapital]),
        total: passiva_total.round(2)
      },
      balanced: balanced
    }
  end

  def format_accounts(accounts)
    accounts.map do |account|
      {
        account_code: account[:code],
        account_name: account[:name],
        balance: account[:balance].round(2)
      }
    end
  end

  def failure(message)
    Result.new(success?: false, data: nil, errors: [ message ])
  end

  def load_stored_balance_sheet
    # Load the stored closing balance sheet for closed fiscal years
    stored_sheet = @fiscal_year.balance_sheets.closing.posted.first
    return nil unless stored_sheet

    # Symbolize keys (JSONB returns string keys, but we work with symbols)
    # and return with additional metadata
    stored_sheet.data.deep_symbolize_keys.merge(
      stored: true,
      posted_at: stored_sheet.posted_at
    )
  end
end
