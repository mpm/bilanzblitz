class AddChartOfAccountsToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_reference :companies, :chart_of_accounts, null: true, foreign_key: true
  end
end
