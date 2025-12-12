class JournalEntriesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_has_company
  before_action :set_company
  before_action :set_journal_entry, only: [ :destroy ]

  def create
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
      :description,
      :vat_split,
      :vat_rate
    )
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
end
