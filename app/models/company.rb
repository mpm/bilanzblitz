class Company < ApplicationRecord
  # Associations
  belongs_to :chart_of_accounts, optional: true
  has_many :company_memberships, dependent: :destroy
  has_many :users, through: :company_memberships
  has_many :fiscal_years, dependent: :destroy
  has_many :accounts, dependent: :destroy
  has_many :account_usages, dependent: :destroy
  has_many :bank_accounts, dependent: :destroy
  has_many :documents, dependent: :destroy
  has_many :journal_entries, dependent: :destroy
  has_many :tax_reports, dependent: :destroy

  # Validations
  validates :name, presence: true
end
