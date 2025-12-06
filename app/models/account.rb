class Account < ApplicationRecord
  # Associations
  belongs_to :company
  has_many :line_items, dependent: :destroy
  has_many :bank_accounts, foreign_key: :ledger_account_id, dependent: :nullify

  # Validations
  validates :code, presence: true, uniqueness: { scope: :company_id }
  validates :name, presence: true
  validates :account_type, presence: true
  validates :tax_rate, numericality: { greater_than_or_equal_to: 0 }

  # Account types for German accounting
  # asset, liability, equity, revenue, expense
  ACCOUNT_TYPES = %w[asset liability equity revenue expense].freeze
  validates :account_type, inclusion: { in: ACCOUNT_TYPES }
end
