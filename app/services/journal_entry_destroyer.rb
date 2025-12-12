class JournalEntryDestroyer
  Result = Struct.new(:success?, :errors, keyword_init: true)

  def initialize(journal_entry:)
    @journal_entry = journal_entry
  end

  def call
    return failure("Cannot delete a posted journal entry (GoBD compliance)") if @journal_entry.posted?
    return failure("Cannot delete entry in closed fiscal year") if @journal_entry.fiscal_year&.closed?

    ActiveRecord::Base.transaction do
      @journal_entry.destroy!
      Result.new(success?: true, errors: [])
    end
  rescue ActiveRecord::RecordNotDestroyed => e
    Result.new(success?: false, errors: e.record.errors.full_messages)
  end

  private

  def failure(message)
    Result.new(success?: false, errors: [ message ])
  end
end
