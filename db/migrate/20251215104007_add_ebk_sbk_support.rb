class AddEbkSbkSupport < ActiveRecord::Migration[8.1]
  def change
    # 1. Create balance_sheets table
    create_table :balance_sheets do |t|
      t.references :fiscal_year, null: false, foreign_key: true
      t.string :sheet_type, null: false      # 'opening' or 'closing'
      t.string :source, null: false          # 'manual', 'calculated', 'carryforward'
      t.date :balance_date, null: false
      t.jsonb :data, null: false, default: {}
      t.jsonb :metadata, default: {}
      t.datetime :posted_at
      t.timestamps

      t.index [ :fiscal_year_id, :sheet_type ], unique: true
      t.index :posted_at
    end

    # 2. Add fields to journal_entries
    add_column :journal_entries, :entry_type, :string, default: "normal", null: false
    add_column :journal_entries, :sequence, :integer
    add_index :journal_entries, [ :fiscal_year_id, :booking_date, :sequence ]

    # 3. Add fields to fiscal_years
    add_column :fiscal_years, :opening_balance_posted_at, :datetime
    add_column :fiscal_years, :closing_balance_posted_at, :datetime
    add_index :fiscal_years, :opening_balance_posted_at
    add_index :fiscal_years, :closing_balance_posted_at

    # 4. Add is_system_account to account_templates
    add_column :account_templates, :is_system_account, :boolean, default: false

    # 5. Add report_type to tax_reports
    add_column :tax_reports, :report_type, :string, default: "vat", null: false
    add_index :tax_reports, [ :company_id, :report_type, :period_type ]

    # 6. Backfill sequence for existing journal entries
    reversible do |dir|
      dir.up do
        JournalEntry.update_all(sequence: 1000)
      end
    end
  end
end
