class EnhanceDocumentsForActiveStorage < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :config, :jsonb, default: {}
    add_column :documents, :issuer_name, :string
    add_column :documents, :issuer_tax_id, :string
    add_column :documents, :processing_status, :string, default: 'pending'
  end
end
