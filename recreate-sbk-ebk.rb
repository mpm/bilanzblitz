# Rails console script to fix fiscal year closing/opening balance entries
# Run this in: ./dc rails console

# ===== CONFIGURATION =====

COMPANY_ID = 2
OLD_FISCAL_YEAR = 2020
NEW_FISCAL_YEAR = 2021

# ===== STEP 1: Load fiscal years =====
puts "Loading fiscal years..."
company = Company.find(COMPANY_ID)
old_fy = company.fiscal_years.find_by(year: OLD_FISCAL_YEAR)
new_fy = company.fiscal_years.find_by(year: NEW_FISCAL_YEAR)

puts "Old FY: #{old_fy.year} (#{old_fy.start_date} - #{old_fy.end_date})"
puts "New FY: #{new_fy.year} (#{new_fy.start_date} - #{new_fy.end_date})"
puts "Company: #{company.name}"

# ===== STEP 2: Find problematic entries =====
puts "\nFinding problematic entries..."

# Find closing entries from old fiscal year
closing_journal_entry = old_fy.journal_entries.find_by(entry_type: "closing")
closing_balance_sheet = old_fy.balance_sheets.find_by(sheet_type: "closing")

# Find opening entries from new fiscal year
opening_journal_entry = new_fy.journal_entries.find_by(entry_type: "opening")
opening_balance_sheet = new_fy.balance_sheets.find_by(sheet_type: "opening")

puts "Closing journal entry: #{closing_journal_entry&.id} (#{closing_journal_entry&.line_items&.count || 0} line items)"
puts "Closing balance sheet: #{closing_balance_sheet&.id}"
puts "Opening journal entry: #{opening_journal_entry&.id} (#{opening_journal_entry&.line_items&.count || 0} line items)"
puts "Opening balance sheet: #{opening_balance_sheet&.id}"

# ===== STEP 3: Confirm before proceeding =====
puts "\n" + "="*60
puts "WARNING: This will delete posted entries (GoBD consideration)"
puts "="*60
puts "\nEntries to be deleted:"
puts "  - Closing journal entry #{closing_journal_entry&.id} from FY #{old_fy.year}"
puts "  - Closing balance sheet #{closing_balance_sheet&.id} from FY #{old_fy.year}"
puts "  - Opening journal entry #{opening_journal_entry&.id} from FY #{new_fy.year}"
puts "  - Opening balance sheet #{opening_balance_sheet&.id} from FY #{new_fy.year}"
puts "\nType 'yes' to continue:"
confirmation = gets.chomp

unless confirmation == 'yes'
  puts "Aborted."
  exit
end

# ===== STEP 4: Delete entries in transaction =====
puts "\nDeleting old entries..."
ActiveRecord::Base.transaction do
  # Delete journal entries (this will cascade delete line_items)
  if closing_journal_entry
    old_fy.closed = false
    old_fy.save

    # Temporarily allow deletion of posted entries
    closing_journal_entry.update_column(:posted_at, nil) if closing_journal_entry.posted_at
    closing_journal_entry.destroy!
    puts "✓ Deleted closing journal entry #{closing_journal_entry.id}"
  end

  if opening_journal_entry
    opening_journal_entry.update_column(:posted_at, nil) if opening_journal_entry.posted_at
    new_fy.closed = false; new_fy.save
    opening_journal_entry.destroy!
    puts "✓ Deleted opening journal entry #{opening_journal_entry.id}"
  end

  # Delete balance sheets
  if closing_balance_sheet
    closing_balance_sheet.update_column(:posted_at, nil) if closing_balance_sheet.posted_at
    closing_balance_sheet.destroy!
    puts "✓ Deleted closing balance sheet #{closing_balance_sheet.id}"
  end

  if opening_balance_sheet
    opening_balance_sheet.update_column(:posted_at, nil) if opening_balance_sheet.posted_at
    opening_balance_sheet.destroy!
    puts "✓ Deleted opening balance sheet #{opening_balance_sheet.id}"
  end

  # Reset fiscal year states
  old_fy.update!(
    closed: false,
    closed_at: nil,
    closing_balance_posted_at: nil
  )
  puts "✓ Reset old fiscal year state"

  new_fy.update!(
    opening_balance_posted_at: nil,
  )
  puts "✓ Reset new fiscal year state"

  puts "\nAll deletions completed successfully!"
end

# ===== STEP 5: Recreate closing and opening balance =====
puts "\n" + "="*60
puts "Recreating closing and opening balance entries..."
puts "="*60

# Run FiscalYearClosingService for old fiscal year
# This will create:
# - SBK journal entry with line items (including net_income → 9805)
# - Closing balance sheet
# - EBK journal entry in new fiscal year with line items (including 9805 → 0860/0868)
# - Opening balance sheet in new fiscal year

result = FiscalYearClosingService.new(
  fiscal_year: old_fy,
  create_next_year_opening: true
).call

puts result.inspect

if result.success?
  puts "\n✅ SUCCESS!"
  puts "\nCreated entries:"

  sbk = result.data[:journal_entry]
  puts "  SBK (FY #{old_fy.year}): Journal Entry ##{sbk.id} with #{sbk.line_items.count} line items"
  puts "    Posted at: #{sbk.posted_at}"

  closing_bs = result.data[:balance_sheet]
  puts "  Closing Balance Sheet (FY #{old_fy.year}): ##{closing_bs.id}"
  puts "    Posted at: #{closing_bs.posted_at}"

  if result.data[:next_year] && result.data[:next_year][:created]
    new_fy.reload
    ebk = new_fy.journal_entries.find_by(entry_type: "opening")
    opening_bs = new_fy.balance_sheets.find_by(sheet_type: "opening")

    puts "  EBK (FY #{new_fy.year}): Journal Entry ##{ebk.id} with #{ebk.line_items.count} line items"
    puts "    Posted at: #{ebk.posted_at}"

    puts "  Opening Balance Sheet (FY #{new_fy.year}): ##{opening_bs.id}"
    puts "    Posted at: #{opening_bs.posted_at}"

    # Show net_income handling
    puts "\n  Net income handling:"
    account_9805_sbk = sbk.line_items.joins(:account).find_by(accounts: { code: "9805" })
    if account_9805_sbk
      puts "    ✓ SBK booked to 9805: #{account_9805_sbk.direction} #{account_9805_sbk.amount}"
    end

    account_9805_ebk = ebk.line_items.joins(:account).find_by(accounts: { code: "9805" })
    if account_9805_ebk
      puts "    ✓ EBK reverses 9805: #{account_9805_ebk.direction} #{account_9805_ebk.amount}"
    end

    account_0860_ebk = ebk.line_items.joins(:account).find_by(accounts: { code: "0860" })
    account_0868_ebk = ebk.line_items.joins(:account).find_by(accounts: { code: "0868" })

    if account_0860_ebk
      puts "    ✓ Profit to 0860: #{account_0860_ebk.direction} #{account_0860_ebk.amount}"
    elsif account_0868_ebk
      puts "    ✓ Loss to 0868: #{account_0868_ebk.direction} #{account_0868_ebk.amount}"
    end
  end

  # Verify debits = credits
  puts "\n  Verification:"
  sbk_debits = sbk.line_items.where(direction: "debit").sum(:amount)
  sbk_credits = sbk.line_items.where(direction: "credit").sum(:amount)
  puts "    SBK: Debits=#{sbk_debits.round(2)}, Credits=#{sbk_credits.round(2)}, Balanced=#{(sbk_debits - sbk_credits).abs < 0.01}"

  if ebk
    ebk_debits = ebk.line_items.where(direction: "debit").sum(:amount)
    ebk_credits = ebk.line_items.where(direction: "credit").sum(:amount)
    puts "    EBK: Debits=#{ebk_debits.round(2)}, Credits=#{ebk_credits.round(2)}, Balanced=#{(ebk_debits - ebk_credits).abs < 0.01}"
  end

  puts "\n✅ All done! Fiscal year closing and opening balance recreated successfully."
else
  puts "\n❌ ERROR: Failed to recreate entries"
  puts "Errors: #{result.errors.join(', ')}"
end
