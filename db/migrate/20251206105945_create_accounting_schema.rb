class CreateAccountingSchema < ActiveRecord::Migration[8.1]
  def change
    # Add first_name and last_name to users table
    add_column :users, :first_name, :string
    add_column :users, :last_name, :string

    # Companies table
    create_table :companies do |t|
      t.string :name, null: false
      t.string :tax_number
      t.string :vat_id
      t.string :commercial_register_number
      t.text :address
      t.timestamps
    end

    # Company Memberships (join table for users and companies)
    create_table :company_memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: true
      t.string :role, default: "accountant"
      t.timestamps
    end

    # Fiscal Years
    create_table :fiscal_years do |t|
      t.references :company, null: false, foreign_key: true
      t.integer :year, null: false
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.boolean :closed, default: false
      t.datetime :closed_at
      t.jsonb :balance_sheet_snapshot
      t.timestamps
    end
    add_index :fiscal_years, [ :company_id, :year ], unique: true

    # Chart of Accounts
    create_table :accounts do |t|
      t.references :company, null: false, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.string :account_type, null: false
      t.decimal :tax_rate, precision: 5, scale: 2, default: 0.0
      t.boolean :is_system_account, default: false
      t.timestamps
    end
    add_index :accounts, [ :company_id, :code ], unique: true

    # Bank Accounts
    create_table :bank_accounts do |t|
      t.references :company, null: false, foreign_key: true
      t.string :iban
      t.string :bic
      t.string :bank_name
      t.string :currency, default: "EUR"
      t.references :ledger_account, foreign_key: { to_table: :accounts }
      t.timestamps
    end

    # Bank Transactions
    create_table :bank_transactions do |t|
      t.references :bank_account, null: false, foreign_key: true
      t.date :booking_date, null: false
      t.date :value_date
      t.decimal :amount, precision: 13, scale: 2, null: false
      t.string :currency, default: "EUR"
      t.string :remote_transaction_id
      t.string :remittance_information
      t.string :counterparty_name
      t.string :counterparty_iban
      t.string :status, default: "pending"
      t.timestamps
    end
    add_index :bank_transactions, :remote_transaction_id, unique: true, name: "index_bank_transactions_on_remote_id"

    # Documents (receipts, invoices)
    create_table :documents do |t|
      t.references :company, null: false, foreign_key: true
      t.string :file_data
      t.string :document_number
      t.date :document_date
      t.string :document_type
      t.decimal :total_amount, precision: 13, scale: 2
      t.timestamps
    end

    # Journal Entries (header for double-entry bookkeeping)
    create_table :journal_entries do |t|
      t.references :company, null: false, foreign_key: true
      t.references :fiscal_year, null: false, foreign_key: true
      t.references :document, foreign_key: true
      t.date :booking_date, null: false
      t.string :description, null: false
      t.datetime :posted_at
      t.timestamps
    end

    # Line Items (the splits in double-entry bookkeeping)
    create_table :line_items do |t|
      t.references :journal_entry, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.references :bank_transaction, foreign_key: true
      t.decimal :amount, precision: 13, scale: 2, null: false
      t.string :direction, null: false
      t.timestamps
    end

    # Tax Reports (VAT reports, annual tax returns)
    create_table :tax_reports do |t|
      t.references :company, null: false, foreign_key: true
      t.string :period_type, null: false
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.string :status, default: "draft"
      t.jsonb :generated_data
      t.datetime :submitted_at
      t.string :elster_transmission_id
      t.timestamps
    end
  end
end
