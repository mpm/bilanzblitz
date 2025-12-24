# Rails console script to recreate EBK from an existing Closing Balance Sheet
# Run this in: ./dc rails console

# ===== CONFIGURATION =====
# Adjust these IDs or years as needed
COMPANY_ID = 2
OLD_FISCAL_YEAR_YEAR = 2019
NEW_FISCAL_YEAR_YEAR = 2020

puts "Loading data..."
company = Company.find(COMPANY_ID)
old_fy = company.fiscal_years.find_by!(year: OLD_FISCAL_YEAR_YEAR)
new_fy = company.fiscal_years.find_by!(year: NEW_FISCAL_YEAR_YEAR)

new_fy.closed = false
new_fy.closed_at = nil
new_fy.save!

puts "Old FY: #{old_fy.year}"
puts "New FY: #{new_fy.year}"

# ===== STEP 1: Get the source data =====
# We get the 'closing' balance sheet from the old year.
# This works even if the year was imported (has no journal entries),
# as long as a BalanceSheet record exists.
old_closing_bs = old_fy.balance_sheets.closing.order(created_at: :desc).first

unless old_closing_bs
  puts "❌ ERROR: No closing balance sheet found for FY #{old_fy.year}"
  exit
end

puts "Found source Balance Sheet: ##{old_closing_bs.id} (Source: #{old_closing_bs.source})"

# IMPORTANT: Ensure keys are symbols for OpeningBalanceCreator
balance_data = old_closing_bs.data.deep_symbolize_keys

# ===== STEP 2: Clean up the NEW year =====
puts "\nCleaning up existing EBK/Opening entries in FY #{new_fy.year}..."

ActiveRecord::Base.transaction do
  # 1. Find and delete existing Opening Journal Entries
  opening_jes = new_fy.journal_entries.where(entry_type: "opening")

  if opening_jes.any?
    puts "  Found #{opening_jes.count} opening journal entries. Deleting..."
    opening_jes.each do |je|
      # Unpost to allow deletion if there are safeguards
      je.update_column(:posted_at, nil) if je.posted_at?
      je.destroy!
    end
  else
    puts "  No existing opening journal entries found."
  end

  # 2. Find and delete existing Opening Balance Sheets
  opening_bss = new_fy.balance_sheets.opening

  if opening_bss.any?
    puts "  Found #{opening_bss.count} opening balance sheets. Deleting..."
    opening_bss.each do |bs|
      bs.update_column(:posted_at, nil) if bs.posted_at?
      bs.destroy!
    end
  else
    puts "  No existing opening balance sheets found."
  end

  # 3. Reset the flag on the fiscal year
  new_fy.update!(opening_balance_posted_at: nil)
  puts "  Reset opening_balance_posted_at on FY #{new_fy.year}"
end

# ===== STEP 3: Recreate EBK =====
puts "\nRecreating EBK from Old FY Balance Sheet Data..."

# We use the service directly, bypassing FiscalYearClosingService
# so we don't trigger recalculation of the old year
creator = OpeningBalanceCreator.new(
  fiscal_year: new_fy,
  balance_data: balance_data,
  source: "carryforward"
)

result = creator.call

if result.success?
  puts "\n✅ SUCCESS!"
  puts "Created new Opening Balance Sheet: ##{result.data[:balance_sheet].id}"
  puts "Created new EBK Journal Entry: ##{result.data[:journal_entry].id}"

  # Verify 9000 account balance matches
  ebk = result.data[:journal_entry]
  debits = ebk.line_items.where(direction: "debit").sum(:amount)
  credits = ebk.line_items.where(direction: "credit").sum(:amount)
  puts "EBK Totals: Debits: #{debits} | Credits: #{credits} (Diff: #{(debits - credits).round(2)})"
else
  puts "\n❌ ERROR: Failed to create opening balance"
  puts "Errors: #{result.errors.join(', ')}"
end
