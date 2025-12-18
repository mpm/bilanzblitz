class JournalEntryCreator
  Result = Struct.new(:success?, :journal_entry, :errors, keyword_init: true)

  def initialize(company:, bank_transaction:, params:)
    @company = company
    @bank_transaction = bank_transaction
    @params = params
  end

  def call
    return failure("Bank transaction is already booked") if @bank_transaction.booked?
    return failure("Bank transaction does not belong to this company") unless valid_company?
    return failure("Bank account has no linked ledger account") unless bank_ledger_account

    fiscal_year = find_fiscal_year
    return failure("No open fiscal year for booking date #{@bank_transaction.booking_date}") unless fiscal_year

    if reverse_charge?
      return failure("Reverse charge input VAT account not found") unless reverse_charge_input_account
      return failure("Reverse charge output VAT account not found") unless reverse_charge_output_account
    elsif @params[:vat_split] && !vat_account
      return failure("VAT account not found - please ensure SKR03 accounts are set up")
    end

    ActiveRecord::Base.transaction do
      @journal_entry = create_journal_entry(fiscal_year)
      create_line_items
      update_bank_transaction_status
      record_account_usage

      Result.new(success?: true, journal_entry: @journal_entry, errors: [])
    end
  rescue ActiveRecord::RecordInvalid => e
    Result.new(success?: false, journal_entry: nil, errors: [ e.message ])
  end

  private

  def create_journal_entry(fiscal_year)
    JournalEntry.create!(
      company: @company,
      fiscal_year: fiscal_year,
      booking_date: @bank_transaction.booking_date,
      description: @params[:description].presence || @bank_transaction.remittance_information || "Bank transaction"
    )
  end

  def create_line_items
    # Bank account line item (linked to the bank transaction)
    # For inflows (positive amount): debit the bank account (asset increases)
    # For outflows (negative amount): credit the bank account (asset decreases)
    bank_direction = @bank_transaction.amount >= 0 ? "debit" : "credit"

    LineItem.create!(
      journal_entry: @journal_entry,
      account: bank_ledger_account,
      amount: @bank_transaction.amount.abs,
      direction: bank_direction,
      bank_transaction: @bank_transaction
    )

    # Counter account line items (with optional VAT split)
    create_counter_line_items
  end

  def create_counter_line_items
    # Counter direction is opposite of bank direction
    # For inflows: credit the revenue/source account
    # For outflows: debit the expense/destination account
    counter_direction = @bank_transaction.amount >= 0 ? "credit" : "debit"

    if reverse_charge?
      create_reverse_charge_line_items(counter_direction)
    elsif @params[:vat_split] && vat_rate > 0
      create_vat_split_line_items(counter_direction)
    else
      create_simple_counter_line_item(counter_direction)
    end
  end

  def create_vat_split_line_items(direction)
    gross_amount = @bank_transaction.amount.abs
    vat_rate_decimal = vat_rate / 100.0
    net_amount = (gross_amount / (1 + vat_rate_decimal)).round(2)
    vat_amount = (gross_amount - net_amount).round(2)

    # Main account (expense/revenue) with net amount
    LineItem.create!(
      journal_entry: @journal_entry,
      account: main_account,
      amount: net_amount,
      direction: direction
    )

    # VAT account with VAT amount
    LineItem.create!(
      journal_entry: @journal_entry,
      account: vat_account,
      amount: vat_amount,
      direction: direction
    )
  end

  def create_simple_counter_line_item(direction)
    LineItem.create!(
      journal_entry: @journal_entry,
      account: main_account,
      amount: @bank_transaction.amount.abs,
      direction: direction
    )
  end

  def create_reverse_charge_line_items(direction)
    # Reverse charge creates 3 additional line items (bank account already created):
    # 1. Main account (e.g., 4600 Werbungskosten) - full amount
    # 2. Input VAT 1577 (Abziehbare Vorsteuer § 13b UStG 19%) - 19% of amount (debit)
    # 3. Output VAT 1787 (Umsatzsteuer nach § 13b UStG 19%) - 19% of amount (credit)
    gross_amount = @bank_transaction.amount.abs
    vat_amount = (gross_amount * 0.19).round(2)

    # Main account with full amount
    LineItem.create!(
      journal_entry: @journal_entry,
      account: main_account,
      amount: gross_amount,
      direction: direction
    )

    # Input VAT (debit for expenses, credit for revenues)
    LineItem.create!(
      journal_entry: @journal_entry,
      account: reverse_charge_input_account,
      amount: vat_amount,
      direction: direction
    )

    # Output VAT (opposite direction)
    opposite_direction = direction == "debit" ? "credit" : "debit"
    LineItem.create!(
      journal_entry: @journal_entry,
      account: reverse_charge_output_account,
      amount: vat_amount,
      direction: opposite_direction
    )
  end

  def find_fiscal_year
    FiscalYear.current_for(company: @company, date: @bank_transaction.booking_date)
  end

  def bank_ledger_account
    @bank_ledger_account ||= @bank_transaction.bank_account.ledger_account
  end

  def main_account
    return @main_account if defined?(@main_account)

    # Support both account_id (legacy) and account_code (new approach)
    if @params[:account_code].present?
      @main_account = find_or_create_account_by_code(@params[:account_code])
    elsif @params[:account_id].present?
      @main_account = @company.accounts.find(@params[:account_id])
    else
      raise ActiveRecord::RecordNotFound, "No account_id or account_code provided"
    end

    @main_account
  end

  def find_or_create_account_by_code(code)
    # First try to find existing account
    account = @company.accounts.find_by(code: code)
    return account if account

    # If not found, try to create from template
    return nil unless @company.chart_of_accounts.present?

    template = @company.chart_of_accounts.account_templates.find_by(code: code)
    return nil unless template

    # Create account from template
    template.add_to_company(@company)
  end

  def vat_account
    return @vat_account if defined?(@vat_account)

    code = vat_account_code
    @vat_account = find_or_create_account_by_code(code)
  end

  def vat_account_code
    is_expense = @bank_transaction.amount < 0

    if is_expense
      # Expense: use Vorsteuer (input tax)
      vat_rate >= 19 ? Account::VAT_ACCOUNTS[:input_19] : Account::VAT_ACCOUNTS[:input_7]
    else
      # Revenue: use Umsatzsteuer (output tax)
      vat_rate >= 19 ? Account::VAT_ACCOUNTS[:output_19] : Account::VAT_ACCOUNTS[:output_7]
    end
  end

  def vat_rate
    @params[:vat_rate].to_f
  end

  def reverse_charge?
    @params[:vat_mode] == "reverse_charge"
  end

  def reverse_charge_input_account
    return @reverse_charge_input_account if defined?(@reverse_charge_input_account)

    code = Account::VAT_ACCOUNTS[:reverse_charge_input_19]
    @reverse_charge_input_account = find_or_create_account_by_code(code)
  end

  def reverse_charge_output_account
    return @reverse_charge_output_account if defined?(@reverse_charge_output_account)

    code = Account::VAT_ACCOUNTS[:reverse_charge_output_19]
    @reverse_charge_output_account = find_or_create_account_by_code(code)
  end

  def update_bank_transaction_status
    @bank_transaction.mark_as_booked!
  end

  def record_account_usage
    AccountUsage.record_usage(company: @company, account: main_account)
  end

  def valid_company?
    @bank_transaction.bank_account.company_id == @company.id
  end

  def failure(message)
    Result.new(success?: false, journal_entry: nil, errors: [ message ])
  end
end
