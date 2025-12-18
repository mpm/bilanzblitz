class AddFiscalYearToTaxReports < ActiveRecord::Migration[8.1]
  def change
    add_reference :tax_reports, :fiscal_year, null: true, foreign_key: true
    add_index :tax_reports, [ :company_id, :fiscal_year_id, :report_type ], name: "index_tax_reports_on_company_fiscal_year_type"
  end
end
