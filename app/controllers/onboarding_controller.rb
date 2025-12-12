class OnboardingController < ApplicationController
  before_action :authenticate_user!
  before_action :redirect_if_has_company, only: [ :new, :create ]

  def new
    render inertia: "Onboarding/CompanySetup"
  end

  def create
    ActiveRecord::Base.transaction do
      # Create the company
      @company = Company.create!(
        name: company_params[:name]
      )

      # Create company membership for current user
      CompanyMembership.create!(
        user: current_user,
        company: @company,
        role: "admin"
      )

      # Create current fiscal year
      current_year = Date.current.year
      @fiscal_year = FiscalYear.create!(
        company: @company,
        year: current_year,
        start_date: Date.new(current_year, 1, 1),
        end_date: Date.new(current_year, 12, 31)
      )

      # Create a generic bank account (1200 SKR03)
      @bank_account_ledger = Account.create!(
        company: @company,
        code: "1200",
        name: "Bank Account",
        account_type: "asset",
        is_system_account: true
      )

      # Create the generic bank account
      @bank_account = BankAccount.create!(
        company: @company,
        bank_name: "Generic Bank Account",
        currency: "EUR",
        ledger_account: @bank_account_ledger
      )
    end

    redirect_to dashboard_path
  rescue ActiveRecord::RecordInvalid => e
    render inertia: "Onboarding/CompanySetup", props: {
      errors: [ e.message ]
    }
  end

  private

  def company_params
    params.require(:company).permit(:name)
  end

  def redirect_if_has_company
    if current_user.companies.any?
      redirect_to dashboard_path
    end
  end
end
