class TaxReport < ApplicationRecord
  # Associations
  belongs_to :company
  belongs_to :fiscal_year, optional: true  # Only for annual reports like KSt

  # Validations
  validates :report_type, presence: true
  validates :period_type, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :status, presence: true
  validate :end_date_after_start_date

  # Report types
  REPORT_TYPES = %w[ustva kst zusammenfassende_meldung umsatzsteuer gewerbesteuer].freeze
  validates :report_type, inclusion: { in: REPORT_TYPES }

  # Period types: monthly, quarterly, annual
  PERIOD_TYPES = %w[monthly quarterly annual].freeze
  validates :period_type, inclusion: { in: PERIOD_TYPES }

  # Status values: draft, submitted, accepted
  STATUSES = %w[draft submitted accepted].freeze
  validates :status, inclusion: { in: STATUSES }

  # Scopes by status
  scope :draft, -> { where(status: "draft") }
  scope :submitted, -> { where(status: "submitted") }
  scope :accepted, -> { where(status: "accepted") }

  # Scopes by report type
  scope :ustva, -> { where(report_type: "ustva") }
  scope :kst, -> { where(report_type: "kst") }
  scope :zusammenfassende_meldung, -> { where(report_type: "zusammenfassende_meldung") }

  # Scope by date range
  scope :for_period, ->(start_date, end_date) {
    where("start_date >= ? AND end_date <= ?", start_date, end_date)
  }

  # Scope by year
  scope :for_year, ->(year) {
    where("EXTRACT(YEAR FROM start_date) = ?", year)
  }

  # Helper methods

  # Human-readable period label
  def period_label
    case period_type
    when "monthly"
      # e.g., "Januar 2025"
      I18n.l(start_date, format: "%B %Y")
    when "quarterly"
      # e.g., "Q1 2025"
      "Q#{quarter} #{year}"
    when "annual"
      # e.g., "2025"
      year.to_s
    else
      "#{start_date} - #{end_date}"
    end
  end

  # Human-readable report type
  def report_type_label
    case report_type
    when "ustva" then "Umsatzsteuervoranmeldung (UStVA)"
    when "kst" then "Körperschaftsteuer (KSt)"
    when "zusammenfassende_meldung" then "Zusammenfassende Meldung (ZM)"
    when "umsatzsteuer" then "Umsatzsteuer-Jahreserklärung"
    when "gewerbesteuer" then "Gewerbesteuererklärung"
    else report_type
    end
  end

  # Quarter number (1-4)
  def quarter
    ((start_date.month - 1) / 3) + 1
  end

  # Year from start_date
  def year
    start_date.year
  end

  # Check if report is editable
  def editable?
    status == "draft"
  end

  # Check if report has been finalized
  def finalized?
    status.in?([ "submitted", "accepted" ])
  end

  private

  def end_date_after_start_date
    return if end_date.blank? || start_date.blank?

    if end_date < start_date
      errors.add(:end_date, "must be after the start date")
    end
  end
end
