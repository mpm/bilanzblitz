# Service to calculate Körperschaftsteuer (KSt / Corporate Income Tax)
# Calculates corporate tax based on GuV data with user-provided adjustments
class KstService
  Result = Struct.new(:success?, :data, :errors, keyword_init: true)

  KST_RATE = 0.15  # 15% corporate tax rate in Germany

  def initialize(company:, fiscal_year:, adjustments: {})
    if company.id != fiscal_year.company_id
      raise "fiscal_year belongs to different company (#{fiscal_year.company_id}) than company the tax report is for (#{company.id})"
    end
    @company = company
    @fiscal_year = fiscal_year
    @adjustments = adjustments
    @net_income = nil
    @balance_sheet_available = false
    @stored_balance_sheet = false
    @guv_available = false
  end

  def call
    return failure("Company is required") unless @company
    return failure("Fiscal year is required") unless @fiscal_year

    # Get financial data (stored or on-the-fly)
    financial_data = get_or_calculate_financials
    return financial_data unless financial_data.success?

    # Extract net income from GuV
    @net_income = financial_data.data[:net_income]

    # Build KSt structure
    kst_data = {
      fiscal_year_id: @fiscal_year.id,
      year: @fiscal_year.year,
      base_data: build_base_data,
      adjustments: build_adjustments,
      calculated: build_calculated_fields,
      metadata: {
        calculation_date: Date.today.to_s,
        stored_balance_sheet: @stored_balance_sheet
      }
    }

    Result.new(success?: true, data: kst_data, errors: [])
  rescue StandardError => e
    Result.new(success?: false, data: nil, errors: [ e.message ])
  end

  private

  def get_or_calculate_financials
    # Try to load stored balance sheet (if fiscal year is closed)
    if @fiscal_year.closed?
      stored_sheet = load_stored_balance_sheet
      if stored_sheet
        @balance_sheet_available = true
        @stored_balance_sheet = true
        @guv_available = stored_sheet[:guv].present?
        return Result.new(
          success?: true,
          data: {
            net_income: stored_sheet.dig(:guv, :net_income) || 0.0
          },
          errors: []
        )
      end
    end

    # Generate on-the-fly using BalanceSheetService
    balance_sheet_result = BalanceSheetService.new(
      company: @company,
      fiscal_year: @fiscal_year
    ).call

    return balance_sheet_result unless balance_sheet_result.success?

    @balance_sheet_available = true
    @guv_available = balance_sheet_result.data[:guv].present?

    Result.new(
      success?: true,
      data: {
        net_income: balance_sheet_result.data.dig(:guv, :net_income) || 0.0
      },
      errors: []
    )
  end

  def load_stored_balance_sheet
    balance_sheet = BalanceSheet
      .where(fiscal_year: @fiscal_year, sheet_type: "closing")
      .order(created_at: :desc)
      .first

    return nil unless balance_sheet

    balance_sheet.data.deep_symbolize_keys
  end

  def build_base_data
    {
      net_income: @net_income.round(2),
      net_income_label: @net_income >= 0 ? "Jahresüberschuss" : "Jahresfehlbetrag",
      balance_sheet_available: @balance_sheet_available,
      guv_available: @guv_available
    }
  end

  def build_adjustments
    adjustments_data = {}

    TaxFormFieldMap.kst_editable_fields.each do |field_key, field_def|
      # Get user-provided value or default
      value = adjustment_value(field_key, field_def[:default_value])

      adjustments_data[field_key] = {
        name: field_def[:name],
        description: field_def[:description],
        value: value.round(2),
        editable: true,
        adjustment_sign: field_def[:adjustment_sign]
      }
    end

    adjustments_data
  end

  def build_calculated_fields
    taxable_income = calculate_taxable_income
    kst_amount = calculate_kst_amount(taxable_income)

    {
      taxable_income: taxable_income.round(2),
      kst_rate: KST_RATE,
      kst_amount: kst_amount.round(2)
    }
  end

  def calculate_taxable_income
    # Start with net income from GuV
    income = @net_income

    # Apply adjustments based on their sign
    TaxFormFieldMap.kst_editable_fields.each do |field_key, field_def|
      value = adjustment_value(field_key, field_def[:default_value])

      case field_def[:adjustment_sign]
      when :add
        income += value
      when :subtract
        income -= value
      end
    end

    income
  end

  def calculate_kst_amount(taxable_income)
    # Corporate tax is 15% of taxable income
    # Cannot be negative (no tax refund for corporate tax)
    tax = taxable_income * KST_RATE
    [ tax, 0.0 ].max
  end

  def adjustment_value(field_key, default_value = 0.0)
    # Get value from @adjustments hash (which uses symbol keys from underscore_keys)
    @adjustments[field_key]&.to_f || default_value
  end

  def failure(message)
    Result.new(success?: false, data: nil, errors: [ message ])
  end
end
