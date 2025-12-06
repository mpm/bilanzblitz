class TaxReport < ApplicationRecord
  # Associations
  belongs_to :company

  # Validations
  validates :period_type, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :status, presence: true
  validate :end_date_after_start_date

  # Period types: monthly, quarterly, annual
  PERIOD_TYPES = %w[monthly quarterly annual].freeze
  validates :period_type, inclusion: { in: PERIOD_TYPES }

  # Status values: draft, submitted, accepted
  STATUSES = %w[draft submitted accepted].freeze
  validates :status, inclusion: { in: STATUSES }

  # Scopes
  scope :draft, -> { where(status: "draft") }
  scope :submitted, -> { where(status: "submitted") }
  scope :accepted, -> { where(status: "accepted") }

  private

  def end_date_after_start_date
    return if end_date.blank? || start_date.blank?

    if end_date < start_date
      errors.add(:end_date, "must be after the start date")
    end
  end
end
