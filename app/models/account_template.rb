class AccountTemplate < ApplicationRecord
  include AccountingConstants

  # Associations
  belongs_to :chart_of_accounts

  # Validations
  validates :code, presence: true, uniqueness: { scope: :chart_of_accounts_id }
  validates :name, presence: true
  validates :account_type, presence: true
  validates :tax_rate, numericality: { greater_than_or_equal_to: 0 }
  validates :account_type, inclusion: { in: ACCOUNT_TYPES }

  # Scopes
  scope :by_code, -> { order(:code) }
  scope :for_chart, ->(chart) { where(chart_of_accounts: chart) }
  scope :of_type, ->(type) { where(account_type: type) }

  def add_to_company(company)
    if company.accounts.where(code: code).exists?
      false
    else
      local_account = Account.new(
        code: code,
        name: name,
        account_type: account_type,
        tax_rate: tax_rate,
        is_system_account: is_system_account || false,
        presentation_rule: presentation_rule
      )
      company.accounts << local_account
      local_account
    end
  end
end
