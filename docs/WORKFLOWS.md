# Workflows

## Fiscal Year Lifecycle

### 1. Create New Fiscal Year

**Access**: `/fiscal_years`

1. Click "New Fiscal Year"
2. Enter start and end dates
3. Select company
4. Save fiscal year
5. Status: **open** (no opening balance yet)

### 2. Create Opening Balance

**Access**: Fiscal year details → "Create Opening Balance"

**Option A: Carryforward from Previous Year** (Recommended)
1. Select previous fiscal year
2. System imports closing balance automatically
3. Review opening balance data
4. Confirm and post

**Option B: Manual Entry**
1. Enter balance sheet data manually
2. Fill in Aktiva (Assets):
   - Anlagevermögen (Fixed Assets)
   - Umlaufvermögen (Current Assets)
3. Fill in Passiva (Liabilities & Equity):
   - Eigenkapital (Equity)
   - Fremdkapital (Liabilities)
4. System validates Aktiva = Passiva
5. Confirm and post

**Result**: Status changes to **open_with_opening**

### 3. Record Transactions

**During the Fiscal Year**:
- Import bank transactions
- Book journal entries
- Link bank transactions to entries
- Upload supporting documents
- Reconcile transactions

### 4. Close Fiscal Year

**Access**: Fiscal year details → "Preview Closing"

1. Click "Preview Closing" to review closing balance
2. System calculates:
   - Closing balance sheet (SBK)
   - GuV (Profit & Loss)
   - Net income/loss
3. Verify Aktiva = Passiva
4. Review GuV sections and totals
5. Click "Confirm Close Fiscal Year"
6. System automatically:
   - Creates SBK journal entries
   - Stores closing balance sheet
   - Marks fiscal year as closed
   - Creates opening balance for next year

**Result**: Status changes to **closed** (immutable)

## Journal Entry Workflow

### 1. Create Journal Entry (Draft)

```ruby
je = JournalEntry.create!(
  company: company,
  fiscal_year: fiscal_year,
  booking_date: Date.today,
  description: "Office supplies from Supplier XYZ"
)
```

### 2. Add Line Items

Each entry must have balanced debits and credits:

```ruby
# Line item 1: Credit bank account (money out)
LineItem.create!(
  journal_entry: je,
  account: bank_account,           # Account "1200 Bank"
  amount: 119.00,
  direction: "credit",
  bank_transaction: bank_tx        # Optional link
)

# Line item 2: Debit expense account
LineItem.create!(
  journal_entry: je,
  account: office_expense_account, # Account "4930 Office Supplies"
  amount: 100.00,
  direction: "debit"
)

# Line item 3: Debit input tax account
LineItem.create!(
  journal_entry: je,
  account: input_tax_account,      # Account "1576 Input Tax 19%"
  amount: 19.00,
  direction: "debit"
)
```

### 3. Post Journal Entry (Make Immutable)

```ruby
je.post!
```

**After Posting**:
- Entry becomes immutable (GoBD compliance)
- Cannot be modified or deleted
- Bank transaction status updates to "booked"

## Bank Transaction Workflow

### 1. Import Transactions

**Status**: pending

Bank transactions are imported from bank feed or CSV.

### 2. Book Transaction

**Via JournalEntryCreator Service**:
- Creates journal entry automatically
- Splits VAT from expenses
- Links bank transaction to line item

**Status**: pending → booked

### 3. Reconcile Transaction

**Optional Step**:
- Verify against source document
- Confirm accuracy
- Mark as reconciled

**Status**: booked → reconciled

## Tax Report Workflow

### Generate UStVA Report

**Access**: `/tax_reports` → "Generate New Report"

1. **Select Report Type**: UStVA
2. **Select Period Type**: Monthly, Quarterly, or Annual
3. **Select Period**: Choose specific date range
4. **Generate Report**: Preview calculations
5. **Review**:
   - Output VAT (Kennziffer 81, 86)
   - Input VAT (Kennziffer 66, 61)
   - Reverse Charge (Kennziffer 46, 47)
   - Net VAT Liability (Kennziffer 83)
6. **Save Report**: Persist to database

**Report Status**: draft (can be updated later)

### Generate KSt Report

**Access**: `/tax_reports` → "Generate New Report"

1. **Select Report Type**: KSt
2. **Select Period Type**: Annual (only option)
3. **Select Fiscal Year**: Choose fiscal year
4. **Generate Report**: Preview calculations with GuV data
5. **Review Base Data**:
   - Net income from GuV
   - Balance sheet availability
6. **Edit Adjustments** (Außerbilanzielle Korrekturen):
   - Non-deductible expenses (adds to taxable income)
   - Tax-free income (subtracts)
   - Loss carryforward (subtracts)
   - Donations (subtracts)
   - Special deductions (subtracts)
7. **Review Calculated Fields**:
   - Taxable income (after adjustments)
   - KSt amount (15% of taxable income)
8. **Save Report**: Persist to database

**Report Status**: draft (can be edited later)

### Edit Saved Report

**For UStVA**: Read-only (amounts calculated from journal entries)
**For KSt**: Can edit adjustment fields and recalculate

## Balance Sheet Report Workflow

**Access**: Reports → Balance Sheet (`/reports/balance_sheet`)

1. **Select Fiscal Year**: Choose from dropdown
2. **View Balance Sheet**:
   - **Aktiva** (Assets):
     - Anlagevermögen (Fixed Assets)
     - Umlaufvermögen (Current Assets)
   - **Passiva** (Liabilities & Equity):
     - Eigenkapital (Equity with net income)
     - Fremdkapital (Liabilities)
3. **View GuV** (below balance sheet):
   - Revenue sections
   - Expense sections
   - Net income/loss
4. **Verify Balance**: Aktiva = Passiva

**Data Source**:
- For open fiscal years: Calculated on-the-fly from posted entries
- For closed fiscal years: Loaded from stored balance sheet

## Opening Balance Workflow

### Manual Entry Mode

1. Navigate to fiscal year → "Create Opening Balance"
2. Select "Manual Entry"
3. Enter Aktiva (Assets):
   - Fixed assets amounts
   - Current assets amounts
4. Enter Passiva (Liabilities & Equity):
   - Equity amounts
   - Liabilities amounts
5. System validates Aktiva = Passiva
6. System generates journal entries with `entry_type: 'opening'`
7. Opening balance posted automatically

### Carryforward Mode

1. Navigate to fiscal year → "Create Opening Balance"
2. Select "Carryforward from Previous Year"
3. Choose previous fiscal year
4. System copies closing balance from previous year
5. Review imported data
6. Confirm to post
7. Opening balance posted automatically

**Result**: Journal entries created with sequence 0-999, using account 9000 as contra account.

## Split Booking Example

**Scenario**: Office supplies purchase for €119 (€100 + €19 VAT)

**Bank Transaction**: -€119 from business account

**Journal Entry**:
1. Credit: Bank Account (1200) - €119 (money out)
2. Debit: Office Supplies (4930) - €100 (expense)
3. Debit: Input VAT 19% (1576) - €19 (deductible VAT)

**Result**: One bank transaction linked to three line items (split across accounts).
