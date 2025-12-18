# Architecture Documentation

## Database Architecture

The application uses a classic double-entry bookkeeping system with PostgreSQL and JSONB support.

### Core Entities

1. **Companies** - Business entities being managed
2. **Users** - Accountants and business owners (linked via CompanyMemberships)
3. **Fiscal Years** - Year-based accounting periods with workflow state tracking
4. **Accounts** - Chart of accounts (SKR03/SKR04 compatible)
5. **Account Templates** - Template accounts for chart of accounts
6. **Bank Accounts** - Physical bank accounts linked to ledger accounts
7. **Bank Transactions** - Individual transactions from bank feeds
8. **Documents** - Scanned receipts, invoices, supporting documentation
9. **Journal Entries** - Bookkeeping transaction headers
10. **Line Items** - The debit/credit splits that make up journal entries
11. **Balance Sheets** - Stored opening and closing balance sheets
12. **Tax Reports** - VAT and annual tax report storage
13. **Account Usages** - Recently used accounts per company

## Key Design Patterns

### Double-Entry Ledger System

Journal entries contain multiple line items. Each line item has:
- An account reference
- An amount
- A direction (debit or credit)
- Optional bank transaction link

The system validates that **debits equal credits** before allowing a journal entry to be posted.

### Bank Reconciliation

The relationship between bank transactions and bookkeeping is solved through line items:

- **Split Booking (1 Transaction → Many Accounts)**: One bank transaction links to one line item (bank asset account), while sibling line items split the amount into expense/VAT accounts
- **Aggregated Booking (Many Transactions → 1 Record)**: Multiple bank transactions each link to separate line items (all bank asset account), balanced against a single invoice line item

### GoBD Compliance (Immutability)

Once a journal entry has a `posted_at` timestamp, it becomes **immutable**:
- Posted entries cannot be modified or deleted
- Line items cannot be changed if their journal entry is posted
- This ensures audit trail compliance with German tax law (GoBD)

Balance sheets with `posted_at` are also immutable for the same reason.

### Bank Transaction States

Bank transactions flow through three states:
1. **pending** - Imported but not yet booked
2. **booked** - Linked to a journal entry
3. **reconciled** - Fully verified against source documents

### Account Usage Tracking

The `AccountUsage` model tracks frequently used accounts per company:
- Records are upserted via `AccountUsage.record_usage(company:, account:)`
- Recently used accounts retrieved via `company.account_usages.recent`
- Enables quick account selection in the booking UI

### VAT Account Constants

Standard SKR03 VAT accounts are defined in `Account::VAT_ACCOUNTS`:
- `1576` - Abziehbare Vorsteuer 19% (Input VAT 19%)
- `1571` - Abziehbare Vorsteuer 7% (Input VAT 7%)
- `1776` - Umsatzsteuer 19% (Output VAT 19%)
- `1771` - Umsatzsteuer 7% (Output VAT 7%)

### Journal Entry Types and Ordering

Journal entries have three types:
- **normal** (sequence: 1000-8999) - Regular business transactions
- **opening** (sequence: 0-999) - Opening balance entries (EBK)
- **closing** (sequence: 9000-9999) - Closing balance entries (SBK)

Entries are ordered by: `booking_date ASC, sequence ASC, id ASC`

### Fiscal Year Workflow States

Fiscal years progress through states:
1. **open** - New fiscal year created, no opening balance yet
2. **open_with_opening** - Opening balance posted, transactions can be recorded
3. **closing_posted** - Closing balance calculated and posted (not yet used)
4. **closed** - Fiscal year is closed, immutable

State transitions tracked via:
- `opening_balance_posted_at`
- `closing_balance_posted_at`
- `closed` / `closed_at`

### Opening and Closing Balance Sheets (EBK/SBK)

**Opening Balance (Eröffnungsbilanz - EBK)**:
- Created at fiscal year start
- Two modes: Manual Entry or Carryforward from previous year
- Uses account 9000 "Saldenvorträge, Sachkonten" as contra account
- Generates journal entries with `entry_type: 'opening'`
- Stored in `balance_sheets` table with `sheet_type: 'opening'`

**Closing Balance (Schlussbilanz - SBK)**:
- Created at fiscal year end
- Automatically calculated from posted journal entries
- Creates closing journal entries that reverse the opening
- Uses account 9000 as contra account
- Generates journal entries with `entry_type: 'closing'`
- Stored in `balance_sheets` table with `sheet_type: 'closing'`
- Fiscal year marked as closed and becomes immutable

**SKR03 Closing Accounts (9000-series)**:
- `9000` - Saldenvorträge, Sachkonten (main EBK/SBK account)
- `9008` - Saldenvorträge, Debitoren
- `9009` - Saldenvorträge, Kreditoren
- `9090` - Summenvortragskonto
- These are system accounts (hidden from normal booking UI)
- Must collectively balance to zero

## Data Integrity Rules

- Debits must equal credits in journal entries
- Posted entries are immutable
- Aktiva must equal Passiva in balance sheets
- Fiscal years must have opening balance before normal entries
- Closing accounts (9000-series) must balance to zero
