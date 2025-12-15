class FiscalYearsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_has_company
  before_action :set_fiscal_year, only: [ :show, :post_opening_balance, :preview_closing, :close ]

  def index
    @company = current_user.companies.first
    @fiscal_years = @company.fiscal_years.order(year: :desc)

    render inertia: "FiscalYears/Index", props: camelize_keys({
      company: {
        id: @company.id,
        name: @company.name
      },
      fiscal_years: @fiscal_years.map { |fy| fiscal_year_props(fy) }
    })
  end

  def show
    @company = current_user.companies.first

    # Get opening and closing balance sheets if they exist
    opening_balance = @fiscal_year.balance_sheets.opening.first
    closing_balance = @fiscal_year.balance_sheets.closing.first

    render inertia: "FiscalYears/Show", props: camelize_keys({
      company: {
        id: @company.id,
        name: @company.name
      },
      fiscal_year: fiscal_year_props(@fiscal_year),
      opening_balance: opening_balance ? balance_sheet_props(opening_balance) : nil,
      closing_balance: closing_balance ? balance_sheet_props(closing_balance) : nil
    })
  end

  def post_opening_balance
    if @fiscal_year.opening_balance_posted?
      return render json: { error: "Opening balance is already posted" }, status: :unprocessable_entity
    end

    # The opening balance should already be created as a draft
    # This action just posts it (makes it immutable)
    opening_balance = @fiscal_year.balance_sheets.opening.draft.first

    unless opening_balance
      return render json: { error: "No draft opening balance found" }, status: :not_found
    end

    if opening_balance.post!
      @fiscal_year.update!(opening_balance_posted_at: Time.current)
      redirect_to fiscal_year_path(@fiscal_year), notice: "Opening balance posted successfully"
    else
      render json: { error: "Failed to post opening balance" }, status: :unprocessable_entity
    end
  end

  def preview_closing
    @company = current_user.companies.first

    unless @fiscal_year.opening_balance_posted?
      return render json: { error: "Opening balance must be posted before closing" }, status: :unprocessable_entity
    end

    if @fiscal_year.closed?
      return render json: { error: "Fiscal year is already closed" }, status: :unprocessable_entity
    end

    # Calculate the closing balance sheet
    result = BalanceSheetService.new(
      company: @company,
      fiscal_year: @fiscal_year
    ).call

    if result.success?
      render inertia: "FiscalYears/PreviewClosing", props: camelize_keys({
        company: {
          id: @company.id,
          name: @company.name
        },
        fiscal_year: fiscal_year_props(@fiscal_year),
        balance_sheet: result.data
      })
    else
      render json: { errors: result.errors }, status: :unprocessable_entity
    end
  end

  def close
    @company = current_user.companies.first

    result = FiscalYearClosingService.new(
      fiscal_year: @fiscal_year,
      user: current_user,
      create_next_year_opening: params[:create_next_year_opening] != "false"
    ).call

    if result.success?
      redirect_to fiscal_year_path(@fiscal_year), notice: "Fiscal year closed successfully"
    else
      render json: { errors: result.errors }, status: :unprocessable_entity
    end
  end

  private

  def set_fiscal_year
    @fiscal_year = current_user.companies.first.fiscal_years.find(params[:id])
  end

  def ensure_has_company
    unless current_user.companies.any?
      redirect_to onboarding_path
    end
  end

  def fiscal_year_props(fiscal_year)
    {
      id: fiscal_year.id,
      year: fiscal_year.year,
      start_date: fiscal_year.start_date,
      end_date: fiscal_year.end_date,
      closed: fiscal_year.closed,
      closed_at: fiscal_year.closed_at,
      opening_balance_posted_at: fiscal_year.opening_balance_posted_at,
      closing_balance_posted_at: fiscal_year.closing_balance_posted_at,
      workflow_state: fiscal_year.workflow_state
    }
  end

  def balance_sheet_props(balance_sheet)
    {
      id: balance_sheet.id,
      sheet_type: balance_sheet.sheet_type,
      source: balance_sheet.source,
      balance_date: balance_sheet.balance_date,
      posted_at: balance_sheet.posted_at,
      data: balance_sheet.data
    }
  end
end
