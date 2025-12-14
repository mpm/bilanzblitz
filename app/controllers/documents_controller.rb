class DocumentsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_has_company
  before_action :set_company
  before_action :set_document, only: [ :update, :destroy ]

  def index
    @documents = @company.documents
      .includes(:journal_entries)
      .with_attached_file
      .order(document_date: :desc, created_at: :desc)

    # Apply filters
    @documents = @documents.where(document_type: params[:type]) if params[:type].present?
    @documents = @documents.unlinked if params[:linked] == "false"

    render inertia: "Documents/Index", props: {
      company: {
        id: @company.id,
        name: @company.name
      },
      documents: @documents.map { |doc| document_json(doc) }
    }
  end

  def create
    @document = @company.documents.build(document_params)

    if @document.save
      render json: {
        success: true,
        document: document_json(@document)
      }
    else
      render json: {
        success: false,
        errors: @document.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def update
    if @document.update(document_update_params)
      render json: {
        success: true,
        document: document_json(@document)
      }
    else
      render json: {
        success: false,
        errors: @document.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def destroy
    if @document.destroy
      @document.file.purge if @document.file.attached?
      @document.thumbnail.purge if @document.thumbnail.attached?
      render json: { success: true }
    else
      render json: {
        success: false,
        errors: @document.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  private

  def ensure_has_company
    unless current_user.companies.any?
      redirect_to onboarding_path
    end
  end

  def set_company
    @company = current_user.companies.first
  end

  def set_document
    @document = @company.documents.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      errors: [ "Document not found" ]
    }, status: :not_found
  end

  def document_json(document)
    {
      id: document.id,
      documentType: document.document_type,
      documentDate: document.document_date,
      documentNumber: document.document_number,
      issuerName: document.issuer_name,
      issuerTaxId: document.issuer_tax_id,
      totalAmount: document.total_amount&.to_f,
      processingStatus: document.processing_status,
      fileName: document.file.attached? ? document.file.filename.to_s : nil,
      fileSize: document.file.attached? ? document.file.byte_size : nil,
      fileUrl: document.file.attached? ? rails_blob_url(document.file) : nil,
      thumbnailUrl: nil, # Stub - will show FileText icon in UI
      linkedToJournal: document.journal_entries.any?,
      journalEntryCount: document.journal_entries.count,
      createdAt: document.created_at
    }
  end

  def document_params
    params.require(:document).permit(
      :file,
      :document_type,
      :document_date,
      :document_number,
      :issuer_name,
      :issuer_tax_id,
      :total_amount,
      :processing_status
    )
  end

  def document_update_params
    # Cannot update file, only metadata
    params.require(:document).permit(
      :document_type,
      :document_date,
      :document_number,
      :issuer_name,
      :issuer_tax_id,
      :total_amount
    )
  end
end
