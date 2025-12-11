class CreateChartOfAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :chart_of_accounts do |t|
      t.string :name, null: false
      t.text :description
      t.string :country_code, null: false

      t.timestamps
    end
    add_index :chart_of_accounts, :country_code
    add_index :chart_of_accounts, :name, unique: true
  end
end
