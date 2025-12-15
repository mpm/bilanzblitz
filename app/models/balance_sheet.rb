class BalanceSheet < ApplicationRecord
  # Associations
  belongs_to :fiscal_year

  # Validations
  validates :sheet_type, presence: true, inclusion: { in: %w[opening closing] }
  validates :source, presence: true, inclusion: { in: %w[manual calculated carryforward] }
  validates :balance_date, presence: true
  validates :data, presence: true

  # Scopes
  scope :opening, -> { where(sheet_type: "opening") }
  scope :closing, -> { where(sheet_type: "closing") }
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
end
