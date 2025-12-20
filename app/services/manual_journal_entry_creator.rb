class ManualJournalEntryCreator
  Result = Struct.new(:success?, :journal_entry, :errors, keyword_init: true)

  def initialize(company:, params:)
    @company = company
    @params = params
  end

  def call
    fiscal_year = find_fiscal_year
    return failure("No open fiscal year for booking date #{@params[:booking_date]}") unless fiscal_year

    ActiveRecord::Base.transaction do
      @journal_entry = create_journal_entry(fiscal_year)
      create_line_items
      record_account_usages

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
      booking_date: @params[:booking_date],
      description: @params[:description]
    )
  end

  def create_line_items
    @params[:line_items].each do |li_params|
      account = find_or_create_account_by_code(li_params[:account_code])

      unless account
        raise ActiveRecord::RecordInvalid.new, "Account with code #{li_params[:account_code]} not found"
      end

      LineItem.create!(
        journal_entry: @journal_entry,
        account: account,
        amount: li_params[:amount],
        direction: li_params[:direction],
        description: li_params[:description]
      )
    end
  end

  def find_fiscal_year
    FiscalYear.current_for(company: @company, date: @params[:booking_date])
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

  def record_account_usages
    # Record all accounts used in this entry
    @journal_entry.line_items.each do |line_item|
      AccountUsage.record_usage(company: @company, account: line_item.account)
    end
  end

  def failure(message)
    Result.new(success?: false, journal_entry: nil, errors: [ message ])
  end
end
