class CreateAccountTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :account_templates do |t|
      t.references :chart_of_accounts, null: false, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.string :account_type, null: false
      t.decimal :tax_rate, precision: 5, scale: 2, default: 0.0
      t.text :description
      t.jsonb :config, default: {}

      t.timestamps
    end

    add_index :account_templates, [:chart_of_accounts_id, :code], unique: true, name: 'index_account_templates_on_chart_and_code'
  end
end
