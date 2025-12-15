class FiscalYear < ApplicationRecord
  # Associations
  belongs_to :company
  has_many :journal_entries, dependent: :destroy
  has_many :balance_sheets, dependent: :destroy

  # Validations
  validates :year, presence: true, uniqueness: { scope: :company_id }
  validates :start_date, presence: true
  validates :end_date, presence: true
  validate :end_date_after_start_date

  # Scopes
  scope :open, -> { where(closed: false) }
  scope :for_date, ->(date) { where("start_date <= ? AND end_date >= ?", date, date) }

  # Class methods
  # Returns a non-closed fiscal year for the given date. Creates the fiscal year if none
  # exists. Returns nil if the year exists and is already closed.
  def self.current_for(company:, date: Date.current)
    year = company.fiscal_years.for_date(date).first
    if !year
      start_date, end_date = company.default_start_end_date(date.year)
      year = new(
        closed: false,
        start_date: start_date,
        end_date: end_date,
        year: date.year
      )
      company.fiscal_years << year
      year.save!
      year
    elsif year.closed
      nil
    else
      year
    end
  end

  # Instance methods
  def opening_balance_posted?
    opening_balance_posted_at.present?
  end

  def closing_balance_posted?
    closing_balance_posted_at.present?
  end

  def workflow_state
    return "closed" if closed?
    return "closing_posted" if closing_balance_posted?
    return "open_with_opening" if opening_balance_posted?
    "open"
  end

  private

  def end_date_after_start_date
    return if end_date.blank? || start_date.blank?

    if end_date < start_date
      errors.add(:end_date, "must be after the start date")
    end
  end
end
