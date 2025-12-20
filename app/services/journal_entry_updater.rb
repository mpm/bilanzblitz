class JournalEntryUpdater
  Result = Struct.new(:success?, :journal_entry, :errors, keyword_init: true)

  def initialize(journal_entry:, params:)
    @journal_entry = journal_entry
    @params = params
  end

  def call
    # Validations
    return failure("Cannot modify posted journal entry") if @journal_entry.posted?
    return failure("Cannot modify entry in closed fiscal year") if @journal_entry.fiscal_year.closed?

    ActiveRecord::Base.transaction do
      update_journal_entry
      replace_line_items
      record_account_usages

      Result.new(success?: true, journal_entry: @journal_entry.reload, errors: [])
    end
  rescue ActiveRecord::RecordInvalid => e
    Result.new(success?: false, journal_entry: nil, errors: [ e.message ])
  end

  private

  def update_journal_entry
    # Re-determine fiscal year if date changed
    fiscal_year = FiscalYear.current_for(
      company: @journal_entry.company,
      date: @params[:booking_date]
    )

    unless fiscal_year
      raise ActiveRecord::RecordInvalid.new, "No open fiscal year for date #{@params[:booking_date]}"
    end

    if fiscal_year.closed?
      raise ActiveRecord::RecordInvalid.new, "Cannot save to closed fiscal year"
    end

    @journal_entry.update!(
      booking_date: @params[:booking_date],
      description: @params[:description],
      fiscal_year: fiscal_year
    )
  end

  def replace_line_items
    # Delete existing line items (only if not posted, validated above)
    @journal_entry.line_items.destroy_all

    # Create new line items from params
    @params[:line_items].each do |li_params|
      account = find_or_create_account(li_params[:account_code])

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

  def find_or_create_account(code)
    # First try to find existing account
    account = @journal_entry.company.accounts.find_by(code: code)
    return account if account

    # If not found, try to create from template
    return nil unless @journal_entry.company.chart_of_accounts.present?

    template = @journal_entry.company.chart_of_accounts.account_templates.find_by(code: code)
    return nil unless template

    # Create account from template
    template.add_to_company(@journal_entry.company)
  end

  def record_account_usages
    # Record all accounts used in this entry
    @journal_entry.line_items.each do |line_item|
      AccountUsage.record_usage(company: @journal_entry.company, account: line_item.account)
    end
  end

  def failure(message)
    Result.new(success?: false, journal_entry: nil, errors: [ message ])
  end
end
