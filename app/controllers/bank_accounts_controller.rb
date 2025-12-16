class BankAccountsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_has_company
  before_action :set_company
  before_action :set_bank_account, only: [ :show, :import_preview, :import ]

  def index
    @bank_accounts = @company.bank_accounts.includes(:ledger_account)

    render inertia: "BankAccounts/Index", props: {
      company: {
        id: @company.id,
        name: @company.name
      },
      bankAccounts: @bank_accounts.map { |ba| bank_account_json(ba) }
    }
  end

  def show
    @transactions = @bank_account.bank_transactions
      .includes(line_item: :journal_entry)
      .order(booking_date: :asc, created_at: :desc)
    @recent_accounts = @company.account_usages.recent.includes(:account).map(&:account).compact
    @fiscal_year = FiscalYear.current_for(company: @company)
    @fiscal_years = @company.fiscal_years.order(year: :desc)

    render inertia: "BankAccounts/Show", props: {
      company: {
        id: @company.id,
        name: @company.name
      },
      bankAccount: bank_account_json(@bank_account),
      transactions: @transactions.map { |tx| transaction_json(tx) },
      recentAccounts: @recent_accounts.map { |a| account_json(a) },
      fiscalYear: @fiscal_year ? fiscal_year_json(@fiscal_year) : nil,
      fiscalYears: @fiscal_years.map { |fy| fiscal_year_json(fy) }
    }
  end

  def import_preview
    csv_data = params[:csv_data]

    begin
      parser = TransactionCsvParser.new(csv_data)
      parsed_transactions = parser.parse
      render json: {
        success: true,
        preview: parsed_transactions.first(5).map { |tx| transaction_preview_json(tx) },
        totalCount: parsed_transactions.count
      }
    rescue => e
      render json: {
        success: false,
        error: e.message
      }, status: :unprocessable_entity
    end
  end

  def import
    csv_data = params[:csv_data]

    begin
      parser = TransactionCsvParser.new(csv_data)
      parsed_transactions = parser.parse
      import_timestamp = Time.current.iso8601

      created_transactions = []
      ActiveRecord::Base.transaction do
        parsed_transactions.each do |tx_data|
          transaction = @bank_account.bank_transactions.create!(
            booking_date: tx_data.booking_date,
            value_date: tx_data.value_date,
            amount: tx_data.amount,
            currency: @bank_account.currency,
            remittance_information: tx_data.remittance_information,
            counterparty_name: tx_data.counterparty_name,
            counterparty_iban: tx_data.counterparty_iban,
            status: "pending",
            config: {
              import: {
                ts: import_timestamp,
                origin: "csv-paste"
              }
            }
          )
          created_transactions << transaction
        end
      end

      render json: {
        success: true,
        importedCount: created_transactions.count
      }
    rescue => e
      render json: {
        success: false,
        error: e.message
      }, status: :unprocessable_entity
    end
  end

  private

  def ensure_has_company
    unless current_user.companies.any?
      redirect_to onboarding_path
    end
  end

  def set_company
    @company = current_user.companies.first
  end

  def set_bank_account
    @bank_account = @company.bank_accounts.find(params[:id])
  end

  def bank_account_json(bank_account)
    {
      id: bank_account.id,
      bankName: bank_account.bank_name,
      iban: bank_account.iban,
      bic: bank_account.bic,
      currency: bank_account.currency,
      ledgerAccount: bank_account.ledger_account ? {
        id: bank_account.ledger_account.id,
        code: bank_account.ledger_account.code,
        name: bank_account.ledger_account.name
      } : nil,
      transactionCount: bank_account.bank_transactions.count
    }
  end

  def transaction_json(transaction)
    journal_entry = transaction.line_item&.journal_entry

    {
      id: transaction.id,
      bookingDate: transaction.booking_date,
      valueDate: transaction.value_date,
      amount: transaction.amount.to_f,
      currency: transaction.currency,
      remittanceInformation: transaction.remittance_information,
      counterpartyName: transaction.counterparty_name,
      counterpartyIban: transaction.counterparty_iban,
      status: transaction.status,
      config: transaction.config,
      journalEntryId: journal_entry&.id,
      journalEntryPosted: journal_entry&.posted?
    }
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

  def fiscal_year_json(fiscal_year)
    {
      id: fiscal_year.id,
      year: fiscal_year.year,
      startDate: fiscal_year.start_date,
      endDate: fiscal_year.end_date,
      closed: fiscal_year.closed
    }
  end

  def transaction_preview_json(tx_data)
    {
      booking_date: tx_data.booking_date&.to_s,
      value_date: tx_data.value_date&.to_s,
      amount: tx_data.amount,
      remittance_information: tx_data.remittance_information,
      counterparty_name: tx_data.counterparty_name,
      counterparty_iban: tx_data.counterparty_iban
    }
  end
end
