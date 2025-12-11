class ChartOfAccounts < ApplicationRecord
  # Associations
  has_many :account_templates, dependent: :destroy
  has_many :companies, dependent: :nullify

  # Validations
  validates :name, presence: true, uniqueness: true
  validates :country_code, presence: true

  # Common country codes for German accounting
  COUNTRY_CODES = %w[DE AT CH].freeze
  validates :country_code, inclusion: { in: COUNTRY_CODES }
end
