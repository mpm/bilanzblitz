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

  # Callbacks
  before_destroy :ensure_not_posted

  # Scopes
  scope :posted, -> { where.not(posted_at: nil) }
  scope :draft, -> { where(posted_at: nil) }

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
end
