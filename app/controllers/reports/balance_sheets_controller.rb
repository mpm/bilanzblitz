class Reports::BalanceSheetsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_has_company

  def index
    @company = current_user.companies.first
    @fiscal_years = @company.fiscal_years.order(year: :desc)

    # Determine selected fiscal year (from params or default to most recent)
    @fiscal_year = if params[:fiscal_year_id].present?
      @fiscal_years.find_by(id: params[:fiscal_year_id])
    else
      @fiscal_years.first
    end

    # Generate balance sheet if fiscal year exists
    @balance_sheet = nil
    @errors = []

    if @fiscal_year
      result = BalanceSheetService.new(
        company: @company,
        fiscal_year: @fiscal_year
      ).call

      if result.success?
        @balance_sheet = result.data
      else
        @errors = result.errors
      end
    end

    render inertia: "Reports/BalanceSheet", props: {
      company: company_json(@company),
      fiscalYears: @fiscal_years.map { |fy| fiscal_year_json(fy) },
      selectedFiscalYearId: @fiscal_year&.id,
      balanceSheet: @balance_sheet ? balance_sheet_json(@balance_sheet) : nil,
      errors: @errors
    }
  end

  private

  def ensure_has_company
    unless current_user.companies.any?
      redirect_to onboarding_path
    end
  end

  def company_json(company)
    {
      id: company.id,
      name: company.name
    }
  end

  def fiscal_year_json(fiscal_year)
    {
      id: fiscal_year.id,
      year: fiscal_year.year,
      startDate: fiscal_year.start_date,
      endDate: fiscal_year.end_date,
      closed: fiscal_year.closed
    }
  end

  def balance_sheet_json(balance_sheet)
    {
      fiscalYear: balance_sheet[:fiscal_year],
      aktiva: {
        anlagevermoegen: balance_sheet[:aktiva][:anlagevermoegen],
        umlaufvermoegen: balance_sheet[:aktiva][:umlaufvermoegen],
        total: balance_sheet[:aktiva][:total]
      },
      passiva: {
        eigenkapital: balance_sheet[:passiva][:eigenkapital],
        fremdkapital: balance_sheet[:passiva][:fremdkapital],
        total: balance_sheet[:passiva][:total]
      },
      balanced: balance_sheet[:balanced]
    }
  end
end
