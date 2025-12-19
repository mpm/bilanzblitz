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

    # Calculate GuV data (includes net_income calculation)
    guv_result = GuVService.new(company: @company, fiscal_year: @fiscal_year).call
    guv_data = guv_result.success? ? guv_result.data : nil

    # Extract net_income from GuV calculation (reuse instead of recalculating)
    net_income = guv_data ? guv_data[:net_income] : 0.0

    # Build balance sheet structure
    data = build_balance_sheet_data(grouped_accounts, net_income, guv_data)

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
    # Build nested sections using AccountMap
    anlagevermoegen = AccountMap.build_nested_section(account_balances, :anlagevermoegen)
    umlaufvermoegen = AccountMap.build_nested_section(account_balances, :umlaufvermoegen)
    eigenkapital = AccountMap.build_nested_section(account_balances, :eigenkapital)

    # Fremdkapital combines Rückstellungen and Verbindlichkeiten
    # For backward compatibility, we keep :fremdkapital as top-level
    # But internally it's built from nested structures
    rueckstellungen = AccountMap.build_nested_section(account_balances, :rueckstellungen)
    verbindlichkeiten = AccountMap.build_nested_section(account_balances, :verbindlichkeiten)

    # Create a fremdkapital section that combines them
    fremdkapital = BalanceSheetSection.new(
      section_key: :fremdkapital,
      section_name: "Fremdkapital",
      level: 1,
      accounts: []
    )
    fremdkapital.add_child(rueckstellungen)
    fremdkapital.add_child(verbindlichkeiten)

    {
      anlagevermoegen: anlagevermoegen,
      umlaufvermoegen: umlaufvermoegen,
      eigenkapital: eigenkapital,
      fremdkapital: fremdkapital
    }
  end

  def build_balance_sheet_data(grouped_sections, net_income, guv_data = nil)
    # grouped_sections now contains BalanceSheetSection instances

    # Build Aktiva (Assets) section using flattened_accounts for backward compatibility
    aktiva_accounts = grouped_sections[:anlagevermoegen].flattened_accounts +
                      grouped_sections[:umlaufvermoegen].flattened_accounts
    aktiva_total = grouped_sections[:anlagevermoegen].total +
                   grouped_sections[:umlaufvermoegen].total

    # Build Passiva (Liabilities & Equity) section
    # Add net income to equity
    eigenkapital_section = grouped_sections[:eigenkapital]
    eigenkapital_accounts = eigenkapital_section.flattened_accounts.dup
    eigenkapital_accounts << {
      code: "net_income",
      name: net_income >= 0 ? "Jahresüberschuss" : "Jahresfehlbetrag",
      type: "equity",
      balance: net_income
    }

    passiva_accounts = eigenkapital_accounts + grouped_sections[:fremdkapital].flattened_accounts
    passiva_total = eigenkapital_section.total + grouped_sections[:fremdkapital].total + net_income

    # Check if balance sheet balances
    balanced = (aktiva_total - passiva_total).abs < 0.01

    result = {
      fiscal_year: {
        id: @fiscal_year.id,
        year: @fiscal_year.year,
        start_date: @fiscal_year.start_date,
        end_date: @fiscal_year.end_date,
        closed: @fiscal_year.closed
      },
      aktiva: {
        anlagevermoegen: format_accounts(grouped_sections[:anlagevermoegen].flattened_accounts),
        umlaufvermoegen: format_accounts(grouped_sections[:umlaufvermoegen].flattened_accounts),
        total: aktiva_total.round(2)
      },
      passiva: {
        eigenkapital: format_accounts(eigenkapital_accounts),
        fremdkapital: format_accounts(grouped_sections[:fremdkapital].flattened_accounts),
        total: passiva_total.round(2)
      },
      balanced: balanced,
      # Add nested structure for future frontend use
      nested_aktiva: {
        anlagevermoegen: grouped_sections[:anlagevermoegen].to_h,
        umlaufvermoegen: grouped_sections[:umlaufvermoegen].to_h
      },
      nested_passiva: {
        eigenkapital: eigenkapital_section.to_h,
        fremdkapital: grouped_sections[:fremdkapital].to_h
      }
    }

    # Add GuV data if available
    result[:guv] = guv_data if guv_data

    result
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
    data = stored_sheet.data.deep_symbolize_keys

    # Backward compatibility: if no GuV data, calculate it on-the-fly
    unless data[:guv]
      guv_result = GuVService.new(company: @company, fiscal_year: @fiscal_year).call
      data[:guv] = guv_result.data if guv_result.success?
    end

    # Return with additional metadata
    data.merge(
      stored: true,
      posted_at: stored_sheet.posted_at
    )
  end
end
