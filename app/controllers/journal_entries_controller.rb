class JournalEntriesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_has_company
  before_action :set_company
  before_action :set_journal_entry, only: [ :destroy, :update, :show ]

  def show
    render json: journal_entry_with_details(@journal_entry)
  end

  def index
    @fiscal_years = @company.fiscal_years.order(year: :desc)

    # Determine selected fiscal year (from params or default to user preference, then most recent open)
    @fiscal_year = if params[:fiscal_year_id].present? && params[:fiscal_year_id] != "all"
      @fiscal_years.find_by(id: params[:fiscal_year_id])
    else
      nil # Show all fiscal years
    end

    # Default to user preference or most recent open fiscal year if no param provided
    if params[:fiscal_year_id].blank?
      preferred_year = preferred_fiscal_year_for_company(@company.id)
      @fiscal_year = if preferred_year
        @fiscal_years.find_by(year: preferred_year) || @fiscal_years.open.first || @fiscal_years.first
      else
        @fiscal_years.open.first || @fiscal_years.first
      end
    end

    # Query journal entries with optional fiscal year filter
    @journal_entries = @company.journal_entries
      .includes(line_items: :account, fiscal_year: nil)
      .then { |q| @fiscal_year ? q.where(fiscal_year_id: @fiscal_year.id) : q }
      .order(booking_date: :asc, id: :asc)

    # Load recent accounts for the modal
    @recent_accounts = @company.account_usages.recent.includes(:account).map(&:account).compact

    render inertia: "JournalEntries/Index", props: camelize_keys({
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
          closed: fy.closed
        }
      },
      selected_fiscal_year_id: @fiscal_year&.id,
      journal_entries: @journal_entries.map { |je| journal_entry_with_details(je) },
      recent_accounts: @recent_accounts.map { |a| account_json(a) }
    })
  end

  def create
    # Check if this is a manual entry or bank transaction booking
    if params[:bank_transaction_id].present?
      create_from_bank_transaction
    else
      create_manual_entry
    end
  end

  def update
    result = JournalEntryUpdater.new(
      journal_entry: @journal_entry,
      params: manual_journal_entry_params
    ).call

    if result.success?
      render json: {
        success: true,
        journalEntry: journal_entry_json(result.journal_entry)
      }
    else
      render json: {
        success: false,
        errors: result.errors
      }, status: :unprocessable_entity
    end
  end

  def destroy
    result = JournalEntryDestroyer.new(journal_entry: @journal_entry).call

    if result.success?
      render json: { success: true }
    else
      render json: {
        success: false,
        errors: result.errors
      }, status: :unprocessable_entity
    end
  end

  private

  def create_from_bank_transaction
    bank_transaction = find_bank_transaction

    unless bank_transaction
      return render json: {
        success: false,
        errors: [ "Bank transaction not found" ]
      }, status: :not_found
    end

    result = JournalEntryCreator.new(
      company: @company,
      bank_transaction: bank_transaction,
      params: journal_entry_params
    ).call

    if result.success?
      render json: {
        success: true,
        journalEntry: journal_entry_json(result.journal_entry)
      }
    else
      render json: {
        success: false,
        errors: result.errors
      }, status: :unprocessable_entity
    end
  end

  def create_manual_entry
    result = ManualJournalEntryCreator.new(
      company: @company,
      params: manual_journal_entry_params
    ).call

    if result.success?
      render json: {
        success: true,
        journalEntry: journal_entry_json(result.journal_entry)
      }
    else
      render json: {
        success: false,
        errors: result.errors
      }, status: :unprocessable_entity
    end
  end

  def ensure_has_company
    redirect_to onboarding_path unless current_user.companies.any?
  end

  def set_company
    @company = current_user.companies.first
  end

  def set_journal_entry
    @journal_entry = @company.journal_entries.find(params[:id])
  end

  def find_bank_transaction
    BankTransaction.joins(bank_account: :company)
      .where(companies: { id: @company.id })
      .find_by(id: params[:bank_transaction_id])
  end

  def journal_entry_params
    params.require(:journal_entry).permit(
      :account_id,
      :account_code,
      :description,
      :vat_split,
      :vat_rate,
      :vat_mode
    )
  end

  def manual_journal_entry_params
    {
      booking_date: params[:journal_entry][:booking_date],
      description: params[:journal_entry][:description],
      line_items: params[:journal_entry][:line_items].map { |li|
        {
          account_code: li[:account_code],
          amount: li[:amount].to_f,
          direction: li[:direction]
        }
      }
    }
  end

  def journal_entry_json(je)
    {
      id: je.id,
      bookingDate: je.booking_date,
      description: je.description,
      postedAt: je.posted_at,
      lineItems: je.line_items.includes(:account).map { |li| line_item_json(li) }
    }
  end

  def journal_entry_with_details(je)
    {
      id: je.id,
      bookingDate: je.booking_date,
      description: je.description,
      postedAt: je.posted_at,
      fiscalYearId: je.fiscal_year_id,
      fiscalYearClosed: je.fiscal_year.closed,
      lineItems: je.line_items.map { |li|
        {
          id: li.id,
          accountCode: li.account.code,
          accountName: li.account.name,
          amount: li.amount.to_f,
          direction: li.direction,
          bankTransactionId: li.bank_transaction_id
        }
      }
    }
  end

  def line_item_json(li)
    {
      id: li.id,
      accountCode: li.account.code,
      accountName: li.account.name,
      amount: li.amount.to_f,
      direction: li.direction,
      bankTransactionId: li.bank_transaction_id
    }
  end

  def account_json(account)
    {
      id: account.id,
      code: account.code,
      name: account.name,
      account_type: account.account_type,
      tax_rate: account.tax_rate
    }
  end
end
