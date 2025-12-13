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

  # Returns dates for the fiscal year start and end dates (for given year).
  # Currently only supports calendar years.
  def default_start_end_date(year)
    start_date = Date.new(year, 1, 1)
    end_date = Date.new(year, 12, 31)
    return start_date, end_date
  end
end
