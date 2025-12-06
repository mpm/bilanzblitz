class BankAccount < ApplicationRecord
  # Associations
  belongs_to :company
  belongs_to :ledger_account, class_name: "Account", optional: true
  has_many :bank_transactions, dependent: :destroy

  # Validations
  validates :currency, presence: true
end
