class AccountUsage < ApplicationRecord
  # Associations
  belongs_to :company
  belongs_to :account

  # Validations
  validates :company_id, uniqueness: { scope: :account_id }
  validates :last_used_at, presence: true

  # Scopes
  scope :recent, -> { order(last_used_at: :desc).limit(10) }

  # Class methods
  def self.record_usage(company:, account:)
    usage = find_or_initialize_by(company: company, account: account)
    usage.usage_count = (usage.usage_count || 0) + 1
    usage.last_used_at = Time.current
    usage.save!
  end
end
