class EnhanceTaxReportsTable < ActiveRecord::Migration[8.1]
  def change
    # Add indexes for common query patterns
    add_index :tax_reports, [ :company_id, :report_type, :start_date ], name: "index_tax_reports_on_company_type_start"
    add_index :tax_reports, [ :company_id, :status ], name: "index_tax_reports_on_company_status"
  end
end
