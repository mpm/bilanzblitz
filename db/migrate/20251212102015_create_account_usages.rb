class CreateAccountUsages < ActiveRecord::Migration[8.1]
  def change
    create_table :account_usages do |t|
      t.references :company, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.integer :usage_count, default: 1
      t.datetime :last_used_at, null: false

      t.timestamps
    end

    add_index :account_usages, [ :company_id, :account_id ], unique: true
    add_index :account_usages, [ :company_id, :last_used_at ]
  end
end
