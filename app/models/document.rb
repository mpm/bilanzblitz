class Document < ApplicationRecord
  # Associations
  belongs_to :company
  has_many :journal_entries, dependent: :nullify

  # ActiveStorage attachments
  has_one_attached :file
  has_one_attached :thumbnail

  # Validations
  validates :company_id, presence: true
  validate :file_must_be_present, on: :create
  validate :file_must_be_pdf, if: -> { file.attached? }

  # Document types: invoice, receipt, credit_note, etc.
  DOCUMENT_TYPES = %w[invoice receipt credit_note contract other].freeze
  validates :document_type, inclusion: { in: DOCUMENT_TYPES }, allow_nil: true

  # Processing statuses
  PROCESSING_STATUSES = %w[pending processing ready failed].freeze
  validates :processing_status, inclusion: { in: PROCESSING_STATUSES }

  # Scopes
  scope :unlinked, -> { left_joins(:journal_entries).where(journal_entries: { id: nil }) }
  scope :by_type, ->(type) { where(document_type: type) }
  scope :ready, -> { where(processing_status: "ready") }

  # Instance methods
  def linked_to_journal?
    journal_entries.any?
  end

  # GoBD Compliance: prevent deletion if linked to posted journal entry
  before_destroy :prevent_delete_if_linked_to_posted_entry

  private

  def file_must_be_present
    unless file.attached?
      errors.add(:file, "must be attached")
    end
  end

  def file_must_be_pdf
    if file.attached? && !file.content_type.in?(%w[application/pdf])
      errors.add(:file, "must be a PDF")
    end
  end

  def prevent_delete_if_linked_to_posted_entry
    if journal_entries.any?(&:posted?)
      errors.add(:base, "Cannot delete document linked to posted journal entry")
      throw(:abort)
    end
  end
end
