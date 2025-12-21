class BalanceSheetService
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

    # If fiscal year is closed, try to load stored balance sheet
    if @fiscal_year.closed?
      stored_sheet = load_stored_balance_sheet
      return Result.new(success?: true, data: stored_sheet, errors: []) if stored_sheet
    end

    # Otherwise calculate on-the-fly
    account_balances = calculate_account_balances
    grouped_accounts = group_by_balance_sheet_sections(account_balances)

    # Calculate GuV data (includes net_income calculation)
    guv_result = GuVService.new(company: @company, fiscal_year: @fiscal_year, only_posted: @only_posted).call
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
    # Only include posted journal entries (GoBD compliance) when only_posted is true
    # Exclude closing entries (they close out accounts, not part of ongoing balance)
    query = @company.accounts
      .joins(line_items: :journal_entry)
      .where(journal_entries: { fiscal_year_id: @fiscal_year.id })

    query = query.where.not(journal_entries: { posted_at: nil }) if @only_posted

    results = query.where.not(journal_entries: { entry_type: "closing" })
      .select(
        "accounts.id",
        "accounts.code",
        "accounts.name",
        "accounts.account_type",
        "accounts.presentation_rule",
        "SUM(CASE WHEN line_items.direction = 'debit' THEN line_items.amount ELSE 0 END) as total_debit",
        "SUM(CASE WHEN line_items.direction = 'credit' THEN line_items.amount ELSE 0 END) as total_credit"
      )
      .group("accounts.id", "accounts.code", "accounts.name", "accounts.account_type", "accounts.presentation_rule")

    # Apply presentation rules to determine balance and position
    results.map do |account|
      total_debit = account.total_debit.to_f
      total_credit = account.total_credit.to_f

      # Get semantic cid for this account from AccountMap
      semantic_cid = AccountMap.cid_for_code(account.code)

      # Determine presentation rule (from DB or infer from account type)
      rule = account.presentation_rule&.to_sym || infer_presentation_rule(account.account_type)

      # Apply the presentation rule to determine resolved position
      position = PresentationRule.apply(rule, total_debit, total_credit, semantic_cid)

      next nil unless position # Skip P&L accounts and zero balances

      {
        id: account.id,
        code: account.code,
        name: account.name,
        type: account.account_type,
        balance: position[:balance],
        resolved_rsid: position[:rsid],
        side: position[:side]
      }
    end.compact.reject { |a| a[:code].start_with?("9") } # Filter 9000-series closing accounts
  end

  def infer_presentation_rule(account_type)
    PresentationRule.infer_from_type(account_type)
  end

  # Legacy method for backward compatibility
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
    # Separate accounts by resolved side (aktiva vs passiva)
    aktiva_accounts = account_balances.select { |a| a[:side] == :aktiva }
    passiva_accounts = account_balances.select { |a| a[:side] == :passiva }

    # Get all top-level categories from AccountMap
    categories = AccountMap.nested_balance_sheet_categories

    aktiva_sections = {}
    passiva_sections = {}

    # Build all aktiva sections using resolved_rsid matching
    categories[:aktiva].each_key do |category_key|
      section = build_section_by_resolved_rsid(aktiva_accounts, category_key, :aktiva)
      aktiva_sections[category_key] = section unless section.empty?
    end

    # Build all passiva sections using resolved_rsid matching
    categories[:passiva].each_key do |category_key|
      section = build_section_by_resolved_rsid(passiva_accounts, category_key, :passiva)
      passiva_sections[category_key] = section unless section.empty?
    end

    { aktiva: aktiva_sections, passiva: passiva_sections }
  end

  # Build a section by matching accounts via resolved_rsid instead of code lookup
  # This allows saldo-dependent accounts to appear in the correct section
  def build_section_by_resolved_rsid(accounts, category_key, side)
    # Get the rsid prefix for this category
    category_rsid = "b.#{side}.#{category_key}"

    # Filter accounts whose resolved_rsid starts with this category's rsid
    matching_accounts = accounts.select do |a|
      a[:resolved_rsid]&.start_with?(category_rsid)
    end

    return BalanceSheetSection.empty(category_key) if matching_accounts.empty?

    # Delegate to AccountMap for the nested structure, but with pre-filtered accounts
    # We transform accounts back to the format AccountMap expects
    account_balances_for_map = matching_accounts.map do |a|
      { code: a[:code], name: a[:name], type: a[:type], balance: a[:balance] }
    end

    AccountMap.build_nested_section(account_balances_for_map, category_key)
  end

  def build_balance_sheet_data(grouped_sections, net_income, guv_data = nil)
    aktiva_sections = grouped_sections[:aktiva]
    passiva_sections = grouped_sections[:passiva]

    # Calculate aktiva total from all aktiva sections
    aktiva_total = aktiva_sections.values.sum(&:total)

    # Add Jahresüberschuss/Jahresfehlbetrag to eigenkapital section
    # Clone the eigenkapital section and add net income as a special account
    eigenkapital_section = passiva_sections[:eigenkapital]
    if eigenkapital_section
      eigenkapital_section_hash = eigenkapital_section.to_h
      # Add net income to the accounts at the top level of eigenkapital
      eigenkapital_section_hash[:accounts] = eigenkapital_section_hash[:accounts].dup
      eigenkapital_section_hash[:accounts] << {
        code: "net_income",
        name: net_income >= 0 ? "Jahresüberschuss" : "Jahresfehlbetrag",
        type: "equity",
        balance: net_income
      }
      eigenkapital_section_hash[:own_total] = (eigenkapital_section_hash[:own_total] || 0) + net_income
      eigenkapital_section_hash[:total] = (eigenkapital_section_hash[:total] || 0) + net_income
      eigenkapital_section_hash[:account_count] += 1
      eigenkapital_section_hash[:total_account_count] += 1
    end

    # Calculate passiva total (including net_income in eigenkapital)
    passiva_total = passiva_sections.values.sum(&:total) + net_income

    # Check if balance sheet balances
    balanced = (aktiva_total - passiva_total).abs < 0.01

    # Build result with nested structure
    result = {
      fiscal_year: {
        id: @fiscal_year.id,
        year: @fiscal_year.year,
        start_date: @fiscal_year.start_date,
        end_date: @fiscal_year.end_date,
        closed: @fiscal_year.closed
      },
      aktiva: {
        sections: aktiva_sections.transform_values(&:to_h),
        total: aktiva_total.round(2)
      },
      passiva: {
        sections: passiva_sections.transform_values do |section|
          if section.section_key == :eigenkapital
            eigenkapital_section_hash
          else
            section.to_h
          end
        end,
        total: passiva_total.round(2)
      },
      balanced: balanced
    }

    # Add GuV data if available
    result[:guv] = guv_data if guv_data

    result
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
      guv_result = GuVService.new(company: @company, fiscal_year: @fiscal_year, only_posted: @only_posted).call
      data[:guv] = guv_result.data if guv_result.success?
    end

    # Return with additional metadata
    data.merge(
      stored: true,
      posted_at: stored_sheet.posted_at
    )
  end
end
