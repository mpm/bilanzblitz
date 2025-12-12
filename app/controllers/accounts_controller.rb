class AccountsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_has_company
  before_action :set_company

  def index
    existing_accounts = @company.accounts.for_booking

    if params[:search].present?
      existing_accounts = existing_accounts.search_by_code_or_name(params[:search])
    end

    existing_accounts = existing_accounts.order(:code).limit(50)

    # Also search template accounts if company has a chart of accounts
    template_accounts = []
    if params[:search].present? && @company.chart_of_accounts.present?
      # Get codes of existing accounts to filter them out from templates
      existing_codes = @company.accounts.pluck(:code)

      # Search in account templates
      template_accounts = @company.chart_of_accounts.account_templates
        .where("code ILIKE :search OR name ILIKE :search", search: "%#{params[:search]}%")
        .where.not(code: existing_codes)
        .order(:code)
        .limit(50)
    end

    render json: {
      accounts: existing_accounts.map { |a| account_json(a, from_template: false) },
      templateAccounts: template_accounts.map { |t| template_account_json(t) }
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

  def account_json(account, from_template: false)
    {
      id: account.id,
      code: account.code,
      name: account.name,
      accountType: account.account_type,
      taxRate: account.tax_rate.to_f,
      fromTemplate: from_template
    }
  end

  def template_account_json(template)
    {
      id: nil,  # No database ID yet
      code: template.code,
      name: template.name,
      accountType: template.account_type,
      taxRate: template.tax_rate.to_f,
      fromTemplate: true
    }
  end
end
