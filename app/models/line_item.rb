class LineItem < ApplicationRecord
  # Associations
  belongs_to :journal_entry
  belongs_to :account
  belongs_to :bank_transaction, optional: true

  # Validations
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :direction, presence: true, inclusion: { in: %w[debit credit] }

  # Callbacks
  before_save :ensure_journal_entry_not_posted

  # Directions for double-entry bookkeeping
  DIRECTIONS = %w[debit credit].freeze

  private

  def ensure_journal_entry_not_posted
    if journal_entry&.posted?
      errors.add(:base, "Cannot modify line items of a posted journal entry (GoBD compliance)")
      throw :abort
    end
  end
end
