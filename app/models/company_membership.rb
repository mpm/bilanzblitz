class CompanyMembership < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :company

  # Validations
  validates :user_id, presence: true
  validates :company_id, presence: true
  validates :role, presence: true
end
