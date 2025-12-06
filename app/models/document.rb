class Document < ApplicationRecord
  # Associations
  belongs_to :company
  has_many :journal_entries, dependent: :nullify

  # Validations
  validates :company_id, presence: true

  # Document types: invoice, receipt, credit_note, etc.
  DOCUMENT_TYPES = %w[invoice receipt credit_note contract other].freeze
  validates :document_type, inclusion: { in: DOCUMENT_TYPES }, allow_nil: true
end
