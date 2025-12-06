# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2025_12_06_105945) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "account_type", null: false
    t.string "code", null: false
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.boolean "is_system_account", default: false
    t.string "name", null: false
    t.decimal "tax_rate", precision: 5, scale: 2, default: "0.0"
    t.datetime "updated_at", null: false
    t.index ["company_id", "code"], name: "index_accounts_on_company_id_and_code", unique: true
    t.index ["company_id"], name: "index_accounts_on_company_id"
  end

  create_table "bank_accounts", force: :cascade do |t|
    t.string "bank_name"
    t.string "bic"
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "EUR"
    t.string "iban"
    t.bigint "ledger_account_id"
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_bank_accounts_on_company_id"
    t.index ["ledger_account_id"], name: "index_bank_accounts_on_ledger_account_id"
  end

  create_table "bank_transactions", force: :cascade do |t|
    t.decimal "amount", precision: 13, scale: 2, null: false
    t.bigint "bank_account_id", null: false
    t.date "booking_date", null: false
    t.string "counterparty_iban"
    t.string "counterparty_name"
    t.datetime "created_at", null: false
    t.string "currency", default: "EUR"
    t.string "remittance_information"
    t.string "remote_transaction_id"
    t.string "status", default: "pending"
    t.datetime "updated_at", null: false
    t.date "value_date"
    t.index ["bank_account_id"], name: "index_bank_transactions_on_bank_account_id"
    t.index ["remote_transaction_id"], name: "index_bank_transactions_on_remote_id", unique: true
  end

  create_table "companies", force: :cascade do |t|
    t.text "address"
    t.string "commercial_register_number"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "tax_number"
    t.datetime "updated_at", null: false
    t.string "vat_id"
  end

  create_table "company_memberships", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "role", default: "accountant"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["company_id"], name: "index_company_memberships_on_company_id"
    t.index ["user_id"], name: "index_company_memberships_on_user_id"
  end

  create_table "documents", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.date "document_date"
    t.string "document_number"
    t.string "document_type"
    t.string "file_data"
    t.decimal "total_amount", precision: 13, scale: 2
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_documents_on_company_id"
  end

  create_table "fiscal_years", force: :cascade do |t|
    t.jsonb "balance_sheet_snapshot"
    t.boolean "closed", default: false
    t.datetime "closed_at"
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.date "end_date", null: false
    t.date "start_date", null: false
    t.datetime "updated_at", null: false
    t.integer "year", null: false
    t.index ["company_id", "year"], name: "index_fiscal_years_on_company_id_and_year", unique: true
    t.index ["company_id"], name: "index_fiscal_years_on_company_id"
  end

  create_table "journal_entries", force: :cascade do |t|
    t.date "booking_date", null: false
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.bigint "document_id"
    t.bigint "fiscal_year_id", null: false
    t.datetime "posted_at"
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_journal_entries_on_company_id"
    t.index ["document_id"], name: "index_journal_entries_on_document_id"
    t.index ["fiscal_year_id"], name: "index_journal_entries_on_fiscal_year_id"
  end

  create_table "line_items", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.decimal "amount", precision: 13, scale: 2, null: false
    t.bigint "bank_transaction_id"
    t.datetime "created_at", null: false
    t.string "direction", null: false
    t.bigint "journal_entry_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_line_items_on_account_id"
    t.index ["bank_transaction_id"], name: "index_line_items_on_bank_transaction_id"
    t.index ["journal_entry_id"], name: "index_line_items_on_journal_entry_id"
  end

  create_table "tax_reports", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "elster_transmission_id"
    t.date "end_date", null: false
    t.jsonb "generated_data"
    t.string "period_type", null: false
    t.date "start_date", null: false
    t.string "status", default: "draft"
    t.datetime "submitted_at"
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_tax_reports_on_company_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name"
    t.string "last_name"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "accounts", "companies"
  add_foreign_key "bank_accounts", "accounts", column: "ledger_account_id"
  add_foreign_key "bank_accounts", "companies"
  add_foreign_key "bank_transactions", "bank_accounts"
  add_foreign_key "company_memberships", "companies"
  add_foreign_key "company_memberships", "users"
  add_foreign_key "documents", "companies"
  add_foreign_key "fiscal_years", "companies"
  add_foreign_key "journal_entries", "companies"
  add_foreign_key "journal_entries", "documents"
  add_foreign_key "journal_entries", "fiscal_years"
  add_foreign_key "line_items", "accounts"
  add_foreign_key "line_items", "bank_transactions"
  add_foreign_key "line_items", "journal_entries"
  add_foreign_key "tax_reports", "companies"
end
