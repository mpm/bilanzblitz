class Reports::BalanceSheetsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_has_company

  def index
    @company = current_user.companies.first
    @fiscal_years = @company.fiscal_years.order(year: :desc)

    # Determine selected fiscal year (from params or default to user preference, then most recent)
    @fiscal_year = if params[:fiscal_year_id].present?
      @fiscal_years.find_by(id: params[:fiscal_year_id])
    else
      preferred_year = preferred_fiscal_year_for_company(@company.id)
      if preferred_year
        @fiscal_years.find_by(year: preferred_year) || @fiscal_years.first
      else
        @fiscal_years.first
      end
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

    # Build props hash with snake_case keys, then transform all to camelCase
    render inertia: "Reports/BalanceSheet", props: camelize_keys({
      company: {
        id: @company.id,
        name: @company.name
      },
      fiscal_years: @fiscal_years.map { |fy|
        {
          id: fy.id,
          year: fy.year,
          start_date: fy.start_date,
          end_date: fy.end_date,
          closed: fy.closed,
          opening_balance_posted_at: fy.opening_balance_posted_at,
          closing_balance_posted_at: fy.closing_balance_posted_at,
          workflow_state: fy.workflow_state
        }
      },
      selected_fiscal_year_id: @fiscal_year&.id,
      balance_sheet: @balance_sheet,
      errors: @errors
    })
  end

  private

  def ensure_has_company
    unless current_user.companies.any?
      redirect_to onboarding_path
    end
  end
end
