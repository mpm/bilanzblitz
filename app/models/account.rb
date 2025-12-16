class Account < ApplicationRecord
  include AccountingConstants

  # SKR03 VAT account codes
  VAT_ACCOUNTS = {
    input_19: "1576",  # Abziehbare Vorsteuer 19%
    input_7: "1571",   # Abziehbare Vorsteuer 7%
    output_19: "1776", # Umsatzsteuer 19%
    output_7: "1771",  # Umsatzsteuer 7%
    reverse_charge_input_19: "1577",  # Abziehbare Vorsteuer § 13b UStG 19%
    reverse_charge_output_19: "1787"  # Umsatzsteuer nach § 13b UStG 19%
  }.freeze

  # Associations
  belongs_to :company
  has_many :line_items, dependent: :destroy
  has_many :bank_accounts, foreign_key: :ledger_account_id, dependent: :nullify
  has_many :account_usages, dependent: :destroy

  # Validations
  validates :code, presence: true, uniqueness: { scope: :company_id }
  validates :name, presence: true
  validates :account_type, presence: true
  validates :tax_rate, numericality: { greater_than_or_equal_to: 0 }
  validates :account_type, inclusion: { in: ACCOUNT_TYPES }

  # Scopes
  scope :search_by_code_or_name, ->(query) {
    where("code ILIKE :q OR name ILIKE :q", q: "%#{query}%")
  }

  scope :for_booking, -> {
    where(account_type: %w[asset liability expense revenue])
  }
end
