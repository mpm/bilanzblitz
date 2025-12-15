class JournalEntry < ApplicationRecord
  # Associations
  belongs_to :company
  belongs_to :fiscal_year
  belongs_to :document, optional: true
  has_many :line_items, dependent: :destroy

  # Validations
  validates :booking_date, presence: true
  validates :description, presence: true
  validate :line_items_must_balance
  validate :fiscal_year_must_be_open, on: :create

  # Callbacks
  before_validation :set_default_sequence, on: :create
  before_destroy :ensure_not_posted
  before_destroy :ensure_fiscal_year_open
  before_destroy :reset_linked_bank_transactions

  # Scopes
  scope :posted, -> { where.not(posted_at: nil) }
  scope :draft, -> { where(posted_at: nil) }
  scope :ordered, -> { order(booking_date: :asc, sequence: :asc, id: :asc) }
  scope :opening, -> { where(entry_type: "opening") }
  scope :closing, -> { where(entry_type: "closing") }
  scope :normal, -> { where(entry_type: "normal") }

  # Methods
  def posted?
    posted_at.present?
  end

  def post!
    return false if posted?

    update(posted_at: Time.current)
  end

  private

  def line_items_must_balance
    return if line_items.empty?

    debits = line_items.select { |li| li.direction == "debit" }.sum(&:amount)
    credits = line_items.select { |li| li.direction == "credit" }.sum(&:amount)

    if debits != credits
      errors.add(:base, "Debits must equal credits (Debits: #{debits}, Credits: #{credits})")
    end
  end

  def ensure_not_posted
    if posted?
      errors.add(:base, "Cannot delete a posted journal entry (GoBD compliance)")
      throw :abort
    end
  end

  def ensure_fiscal_year_open
    if fiscal_year&.closed?
      errors.add(:base, "Cannot delete journal entry in a closed fiscal year")
      throw :abort
    end
  end

  def fiscal_year_must_be_open
    if fiscal_year&.closed?
      errors.add(:fiscal_year, "is closed and cannot accept new entries")
    end
  end

  def reset_linked_bank_transactions
    line_items.each do |line_item|
      line_item.bank_transaction&.reset_to_pending!
    end
  end

  def set_default_sequence
    return if sequence.present?

    self.sequence = case entry_type
    when "opening"
      0
    when "closing"
      9000
    else
      1000
    end
  end
end
