class OpeningBalancesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_has_company
  before_action :set_fiscal_year

  def new
    @company = current_user.companies.first

    # Check if opening balance already exists
    if @fiscal_year.opening_balance_posted?
      redirect_to fiscal_year_path(@fiscal_year), alert: "Opening balance already posted for this fiscal year"
      return
    end

    # Check if there's a previous fiscal year to carryforward from
    @previous_fiscal_year = @company.fiscal_years
      .where(year: @fiscal_year.year - 1)
      .where.not(closing_balance_posted_at: nil)
      .first

    render inertia: "OpeningBalances/Form", props: camelize_keys({
      company: {
        id: @company.id,
        name: @company.name
      },
      fiscal_year: {
        id: @fiscal_year.id,
        year: @fiscal_year.year,
        start_date: @fiscal_year.start_date,
        end_date: @fiscal_year.end_date
      },
      previous_fiscal_year: @previous_fiscal_year ? {
        id: @previous_fiscal_year.id,
        year: @previous_fiscal_year.year,
        has_closing_balance: @previous_fiscal_year.closing_balance_posted?
      } : nil
    })
  end

  def create
    @company = current_user.companies.first

    # Check if opening balance already exists
    if @fiscal_year.opening_balance_posted?
      return render json: { error: "Opening balance already posted for this fiscal year" }, status: :unprocessable_entity
    end

    # Determine source and balance data
    source = params[:source] || "manual"
    balance_data = if source == "carryforward"
      fetch_previous_year_balance
    else
      parse_manual_balance_data
    end

    unless balance_data
      return render json: { error: "Invalid balance data" }, status: :unprocessable_entity
    end

    # Create opening balance using the service
    result = OpeningBalanceCreator.new(
      fiscal_year: @fiscal_year,
      balance_data: balance_data,
      source: source
    ).call

    if result.success?
      redirect_to fiscal_year_path(@fiscal_year), notice: "Opening balance created successfully"
    else
      render json: { errors: result.errors }, status: :unprocessable_entity
    end
  end

  private

  def set_fiscal_year
    @fiscal_year = current_user.companies.first.fiscal_years.find(params[:fiscal_year_id])
  end

  def ensure_has_company
    unless current_user.companies.any?
      redirect_to onboarding_path
    end
  end

  def fetch_previous_year_balance
    previous_year = @company.fiscal_years
      .where(year: @fiscal_year.year - 1)
      .where.not(closing_balance_posted_at: nil)
      .first

    return nil unless previous_year

    # Get the closing balance sheet
    closing_balance = previous_year.balance_sheets.closing.posted.first
    return nil unless closing_balance

    # Return the balance sheet data with symbolized keys
    # (JSONB returns string keys, but our services expect symbols)
    closing_balance.data.deep_symbolize_keys
  end

  def parse_manual_balance_data
    # Parse balance data from params
    # Expected format:
    # {
    #   aktiva: {
    #     anlagevermoegen: [{account_code: "0027", balance: 5000.00}, ...],
    #     umlaufvermoegen: [{account_code: "1200", balance: 50000.00}, ...]
    #   },
    #   passiva: {
    #     eigenkapital: [{account_code: "0800", balance: 25000.00}, ...],
    #     rueckstellungen: [{account_code: "0950", balance: 10000.00}, ...],
    #     verbindlichkeiten: [{account_code: "1600", balance: 20000.00}, ...]
    #   }
    # }

    # Convert camelCase keys from frontend to snake_case for backend processing
    balance_params = underscore_keys(params.require(:balance_data).permit!)

    {
      aktiva: {
        anlagevermoegen: parse_account_section(balance_params[:aktiva][:anlagevermoegen]),
        umlaufvermoegen: parse_account_section(balance_params[:aktiva][:umlaufvermoegen])
      },
      passiva: {
        eigenkapital: parse_account_section(balance_params[:passiva][:eigenkapital]),
        rueckstellungen: parse_account_section(balance_params[:passiva][:rueckstellungen]),
        verbindlichkeiten: parse_account_section(balance_params[:passiva][:verbindlichkeiten])
      }
    }
  rescue ActionController::ParameterMissing, NoMethodError
    nil
  end

  def parse_account_section(section_params)
    return [] unless section_params

    section_params.map do |account_params|
      {
        account_code: account_params[:account_code],
        account_name: account_params[:account_name],
        balance: account_params[:balance].to_f
      }
    end
  end
end
