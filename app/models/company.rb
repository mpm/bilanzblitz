class Company < ApplicationRecord
  # Associations
  has_many :company_memberships, dependent: :destroy
  has_many :users, through: :company_memberships
  has_many :fiscal_years, dependent: :destroy
  has_many :accounts, dependent: :destroy
  has_many :bank_accounts, dependent: :destroy
  has_many :documents, dependent: :destroy
  has_many :journal_entries, dependent: :destroy
  has_many :tax_reports, dependent: :destroy

  # Validations
  validates :name, presence: true
end
