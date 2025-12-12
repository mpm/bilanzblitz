class AccountsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_has_company
  before_action :set_company

  def index
    accounts = @company.accounts.for_booking

    if params[:search].present?
      accounts = accounts.search_by_code_or_name(params[:search])
    end

    accounts = accounts.order(:code).limit(50)

    render json: {
      accounts: accounts.map { |a| account_json(a) }
    }
  end

  def recent
    recent_accounts = @company.account_usages
      .recent
      .includes(:account)
      .map(&:account)
      .compact

    render json: {
      accounts: recent_accounts.map { |a| account_json(a) }
    }
  end

  private

  def ensure_has_company
    redirect_to onboarding_path unless current_user.companies.any?
  end

  def set_company
    @company = current_user.companies.first
  end

  def account_json(account)
    {
      id: account.id,
      code: account.code,
      name: account.name,
      accountType: account.account_type,
      taxRate: account.tax_rate.to_f
    }
  end
end
