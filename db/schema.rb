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

ActiveRecord::Schema[8.1].define(version: 2025_12_14_220215) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "account_templates", force: :cascade do |t|
    t.string "account_type", null: false
    t.bigint "chart_of_accounts_id", null: false
    t.string "code", null: false
    t.jsonb "config", default: {}
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.decimal "tax_rate", precision: 5, scale: 2, default: "0.0"
    t.datetime "updated_at", null: false
    t.index ["chart_of_accounts_id", "code"], name: "index_account_templates_on_chart_and_code", unique: true
    t.index ["chart_of_accounts_id"], name: "index_account_templates_on_chart_of_accounts_id"
  end

  create_table "account_usages", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.datetime "last_used_at", null: false
    t.datetime "updated_at", null: false
    t.integer "usage_count", default: 1
    t.index ["account_id"], name: "index_account_usages_on_account_id"
    t.index ["company_id", "account_id"], name: "index_account_usages_on_company_id_and_account_id", unique: true
    t.index ["company_id", "last_used_at"], name: "index_account_usages_on_company_id_and_last_used_at"
    t.index ["company_id"], name: "index_account_usages_on_company_id"
  end

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

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
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
    t.jsonb "config", default: {}
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

  create_table "chart_of_accounts", force: :cascade do |t|
    t.string "country_code", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["country_code"], name: "index_chart_of_accounts_on_country_code"
    t.index ["name"], name: "index_chart_of_accounts_on_name", unique: true
  end

  create_table "companies", force: :cascade do |t|
    t.text "address"
    t.bigint "chart_of_accounts_id"
    t.string "commercial_register_number"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "tax_number"
    t.datetime "updated_at", null: false
    t.string "vat_id"
    t.index ["chart_of_accounts_id"], name: "index_companies_on_chart_of_accounts_id"
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
    t.jsonb "config", default: {}
    t.datetime "created_at", null: false
    t.date "document_date"
    t.string "document_number"
    t.string "document_type"
    t.string "file_data"
    t.string "issuer_name"
    t.string "issuer_tax_id"
    t.string "processing_status", default: "pending"
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
    t.jsonb "config", default: {}, null: false
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

  add_foreign_key "account_templates", "chart_of_accounts", column: "chart_of_accounts_id"
  add_foreign_key "account_usages", "accounts"
  add_foreign_key "account_usages", "companies"
  add_foreign_key "accounts", "companies"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "bank_accounts", "accounts", column: "ledger_account_id"
  add_foreign_key "bank_accounts", "companies"
  add_foreign_key "bank_transactions", "bank_accounts"
  add_foreign_key "companies", "chart_of_accounts", column: "chart_of_accounts_id"
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
