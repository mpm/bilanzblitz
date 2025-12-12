class DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_has_company

  def index
    @company = current_user.companies.first
    @fiscal_year = @company.fiscal_years.order(year: :desc).first
    @bank_account = @company.bank_accounts.first

    render inertia: "Dashboard/Index", props: {
      company: {
        id: @company.id,
        name: @company.name
      },
      fiscalYear: @fiscal_year ? {
        id: @fiscal_year.id,
        year: @fiscal_year.year,
        startDate: @fiscal_year.start_date,
        endDate: @fiscal_year.end_date
      } : nil,
      bankAccount: @bank_account ? {
        id: @bank_account.id,
        bankName: @bank_account.bank_name,
        currency: @bank_account.currency
      } : nil
    }
  end

  private

  def ensure_has_company
    unless current_user.companies.any?
      redirect_to onboarding_path
    end
  end
end
