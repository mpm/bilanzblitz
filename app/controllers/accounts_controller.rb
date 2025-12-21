class AccountsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_has_company
  before_action :set_company

  def index
    # Check if this is an API request (JSON) or page request (HTML/Inertia)
    respond_to do |format|
      format.json do
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

      format.html do
        # Render Inertia page for accounts overview
        accounts = @company.accounts.order(:code)

        render inertia: "Accounts/Index", props: {
          company: { id: @company.id, name: @company.name },
          accounts: accounts.map { |a| account_detail_json(a) }
        }
      end
    end
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

  def show
    @account = @company.accounts.find(params[:id])
    @fiscal_years = @company.fiscal_years.order(start_date: :desc)
    @selected_fiscal_year_id = params[:fiscal_year_id]&.to_i

    # Fetch ledger data using same logic as ledger action
    @ledger_data = fetch_ledger_data(@account, @selected_fiscal_year_id)

    render inertia: "Accounts/Show", props: {
      company: { id: @company.id, name: @company.name },
      fiscalYears: @fiscal_years.map { |fy| fiscal_year_json(fy) },
      selectedFiscalYearId: @selected_fiscal_year_id,
      account: account_detail_json(@account),
      ledgerData: @ledger_data
    }
  end

  def ledger
    @account = @company.accounts.find(params[:id])
    fiscal_year_id = params[:fiscal_year_id]&.to_i

    ledger_data = fetch_ledger_data(@account, fiscal_year_id)

    render json: ledger_data
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

  def fetch_ledger_data(account, fiscal_year_id = nil)
    # Build query with eager loading to avoid N+1
    line_items = LineItem
      .joins(:journal_entry)
      .includes(:journal_entry, :account)
      .where(account_id: account.id)
      .where(journal_entries: { company_id: @company.id })
    # .where.not(journal_entries: { posted_at: nil }) # Only posted entries (GoBD)

    # Filter by fiscal year if provided
    line_items = line_items.where(journal_entries: { fiscal_year_id: fiscal_year_id }) if fiscal_year_id

    # Order by date, journal entry, then line item
    line_items = line_items.order(
      "journal_entries.booking_date ASC",
      "journal_entries.id ASC",
      "line_items.id ASC"
    )

    # Group by journal entry
    grouped = line_items.group_by(&:journal_entry)

    # Calculate balance
    debits = line_items.where(direction: "debit").sum(:amount)
    credits = line_items.where(direction: "credit").sum(:amount)

    # Get semantic category and presentation rule
    semantic_cid = AccountMap.cid_for_code(account.code)
    rule = account.presentation_rule&.to_sym || infer_presentation_rule(account.account_type)
    position = PresentationRule.apply(rule, debits, credits, semantic_cid)
    balance = position ? position[:balance] : 0.0

    # Get fiscal year info if filtered
    fiscal_year = fiscal_year_id ? @company.fiscal_years.find_by(id: fiscal_year_id) : nil

    {
      account: account_detail_json(account),
      fiscalYear: fiscal_year ? fiscal_year_json(fiscal_year) : nil,
      balance: balance,
      lineItemGroups: grouped.map do |journal_entry, items|
        {
          journalEntryId: journal_entry.id,
          bookingDate: journal_entry.booking_date,
          description: journal_entry.description,
          postedAt: journal_entry.posted_at,
          fiscalYearClosed: journal_entry.fiscal_year.closed?,
          lineItems: items.map { |li| line_item_json(li) }
        }
      end
    }
  end

  def infer_presentation_rule(account_type)
    case account_type
    when "asset" then :asset_only
    when "liability" then :liability_only
    when "equity" then :equity_only
    when "expense", "revenue" then :pnl_only
    end
  end

  def account_detail_json(account)
    {
      id: account.id,
      code: account.code,
      name: account.name,
      accountType: account.account_type
    }
  end

  def line_item_json(line_item)
    {
      id: line_item.id,
      amount: line_item.amount.to_f,
      direction: line_item.direction,
      description: line_item.description,
      accountCode: line_item.account.code,
      accountName: line_item.account.name
    }
  end

  def fiscal_year_json(fiscal_year)
    {
      id: fiscal_year.id,
      year: fiscal_year.year,
      startDate: fiscal_year.start_date.to_s,
      endDate: fiscal_year.end_date.to_s,
      closed: fiscal_year.closed?
    }
  end
end
