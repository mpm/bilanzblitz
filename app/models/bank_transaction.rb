class BankTransaction < ApplicationRecord
  # Associations
  belongs_to :bank_account
  has_one :line_item, dependent: :nullify

  # Validations
  validates :booking_date, presence: true
  validates :amount, presence: true, numericality: true
  validates :currency, presence: true
  validates :status, presence: true

  # Status values: pending, booked, reconciled
  STATUSES = %w[pending booked reconciled].freeze
  validates :status, inclusion: { in: STATUSES }

  # Scopes
  scope :pending, -> { where(status: "pending") }
  scope :booked, -> { where(status: "booked") }
  scope :reconciled, -> { where(status: "reconciled") }
end
