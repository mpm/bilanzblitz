# BilanzBlitz - German Accounting Service

## Project Overview

BilanzBlitz is a comprehensive accounting and tax management application designed specifically for German GmbHs (limited liability companies) and UGs (entrepreneurial companies). The application enables businesses to manage their complete accounting workflow, from bank transaction synchronization to annual tax filings.

### Core Features

- **Bank Account Synchronization**: Connect and sync bank accounts to automatically import transactions
- **Receipt & Invoice Management**: Upload and manage receipts, invoices, and other financial documents
- **Double-Entry Bookkeeping**: Complete ledger system with journal entries and line items
- **Transaction Splitting**: Split bank transactions across multiple accounts (e.g., separating VAT from expenses)
- **Bank Reconciliation**: Link bank transactions to bookkeeping entries
- **Opening Balance Sheets (EBK)**: Create opening balances manually or import from previous year
- **Closing Balance Sheets (SBK)**: Automated fiscal year closing with proper German accounting procedures
- **Fiscal Year Management**: Complete workflow from opening to closing with state tracking
- **Balance Sheet Reports**: Generate balance sheets (Bilanz) following German GmbH standards with SKR03 account mapping
- **Balance Sheet Persistence**: Store and retrieve opening and closing balance sheets
- **GuV Reports**: Generate Profit & Loss statements (Gewinn- und Verlustrechnung) using Gesamtkostenverfahren (Total Cost Method) according to § 275 Abs. 2 HGB
- **VAT Reports**: Generate periodic VAT reports (Umsatzsteuervoranmeldung)
- **Annual Tax Returns**: Prepare and generate annual tax filings
- **GoBD Compliance**: Immutable posted entries and balance sheets to comply with German accounting regulations

## Technology Stack

### Backend
- **Ruby on Rails 8.1** - Application framework
- **PostgreSQL** - Database with JSONB support for flexible data storage
- **Devise** - User authentication
- **Inertia Rails** - Modern monolith architecture (Rails backend + SPA frontend)

### Frontend
- **React with TypeScript** - Component-based UI
- **Vite Rails** - Fast frontend build tooling
- **Inertia.js** - SPA experience without building an API
- **Tailwind CSS** - Utility-first CSS framework
- **shadcn/ui** - High-quality, accessible UI components

### Development Environment
- **Dev Container** - Consistent development environment using Docker

## Database Architecture

The application uses a classic double-entry bookkeeping system:

### Core Entities

1. **Companies** - Business entities being managed
2. **Users** - Accountants and business owners (linked via CompanyMemberships)
3. **Fiscal Years** - Year-based accounting periods with workflow state tracking and closing capability
4. **Accounts** - Chart of accounts (SKR03/SKR04 compatible)
5. **Account Templates** - Template accounts in chart of accounts (used to create company-specific accounts)
6. **Bank Accounts** - Physical bank accounts linked to ledger accounts
7. **Bank Transactions** - Individual transactions from bank feeds (status: pending → booked → reconciled)
8. **Documents** - Scanned receipts, invoices, and supporting documentation
9. **Journal Entries** - Bookkeeping transaction headers (can be posted for immutability, with entry_type: normal/opening/closing)
10. **Line Items** - The debit/credit splits that make up journal entries
11. **Balance Sheets** - Stored opening and closing balance sheets (Eröffnungsbilanz/Schlussbilanz)
12. **Tax Reports** - VAT and annual tax report storage (with report_type field)
13. **Account Usages** - Tracks recently used accounts per company for quick selection during booking

### Key Design Decisions

#### Double-Entry Ledger System
Journal entries contain multiple line items. Each line item has:
- An account reference
- An amount
- A direction (debit or credit)
- Optional bank transaction link

The system validates that debits equal credits before allowing a journal entry to be posted.

#### Bank Reconciliation
The relationship between bank transactions and bookkeeping is solved through line items:
- **Split Booking (1 Transaction → Many Accounts)**: One bank transaction links to one line item (bank asset account), while sibling line items split the amount into expense/VAT accounts
- **Aggregated Booking (Many Transactions → 1 Record)**: Multiple bank transactions each link to separate line items (all bank asset account), balanced against a single invoice line item

#### GoBD Compliance
Once a journal entry has a `posted_at` timestamp, it becomes immutable:
- Posted entries cannot be modified or deleted
- Line items cannot be changed if their journal entry is posted
- This ensures audit trail compliance with German tax law (GoBD - Grundsätze zur ordnungsmäßigen Führung und Aufbewahrung von Büchern)

#### Bank Transaction Booking Workflow
Bank transactions flow through the following states:
1. **pending** - Imported but not yet booked
2. **booked** - Linked to a journal entry
3. **reconciled** - Fully verified against source documents

The booking process uses service classes:
- `JournalEntryCreator` - Creates journal entries from bank transactions with automatic VAT splits
- `JournalEntryDestroyer` - Safely deletes journal entries (resets bank transaction to pending)

#### Account Usage Tracking
The `AccountUsage` model tracks which accounts are frequently used per company:
- Records are upserted via `AccountUsage.record_usage(company:, account:)`
- Recently used accounts are retrieved via `company.account_usages.recent`
- This enables quick account selection in the booking UI

#### VAT Account Constants
Standard SKR03 VAT accounts are defined in `Account::VAT_ACCOUNTS`:
- `1576` - Abziehbare Vorsteuer 19% (Input VAT 19%)
- `1571` - Abziehbare Vorsteuer 7% (Input VAT 7%)
- `1776` - Umsatzsteuer 19% (Output VAT 19%)
- `1771` - Umsatzsteuer 7% (Output VAT 7%)

#### Journal Entry Types and Ordering
Journal entries have three types that determine their purpose and ordering:
- **normal** (sequence: 1000-8999) - Regular business transactions
- **opening** (sequence: 0-999) - Opening balance entries (Eröffnungsbilanzkonto - EBK)
- **closing** (sequence: 9000-9999) - Closing balance entries (Schlussbilanzkonto - SBK)

Entries are ordered by: `booking_date ASC, sequence ASC, id ASC`
- This ensures EBK entries always appear first on the opening date
- SBK entries always appear last on the closing date
- Normal transactions appear in between based on booking date

#### Fiscal Year Workflow States
Fiscal years progress through five workflow states:

1. **open** - New fiscal year created, no opening balance yet
2. **open_with_opening** - Opening balance posted, transactions can be recorded
3. **closing_posted** - Closing balance has been calculated and posted (not yet used)
4. **closed** - Fiscal year is closed, immutable

State transitions are tracked via:
- `opening_balance_posted_at` - Timestamp when opening balance was posted
- `closing_balance_posted_at` - Timestamp when closing balance was posted
- `closed` / `closed_at` - Final closing timestamp

#### Opening and Closing Balance Sheets (EBK/SBK)
The application supports German-standard opening and closing balance sheets:

**Opening Balance (Eröffnungsbilanz - EBK)**:
- Created at the start of a fiscal year
- Two modes:
  - **Manual Entry**: User manually enters balance sheet data
  - **Carryforward**: Automatically imports closing balance from previous year
- Uses account 9000 "Saldenvorträge, Sachkonten" as contra account
- Generates journal entries with `entry_type: 'opening'`
- Stored in `balance_sheets` table with `sheet_type: 'opening'`

**Closing Balance (Schlussbilanz - SBK)**:
- Created at fiscal year end
- Automatically calculated from posted journal entries
- Creates closing journal entries that reverse the opening (credit assets, debit liabilities/equity)
- Uses account 9000 as contra account
- Generates journal entries with `entry_type: 'closing'`
- Stored in `balance_sheets` table with `sheet_type: 'closing'`
- Fiscal year is marked as closed and becomes immutable

**SKR03 Closing Accounts (9000-series)**:
- `9000` - Saldenvorträge, Sachkonten (main EBK/SBK account)
- `9008` - Saldenvorträge, Debitoren
- `9009` - Saldenvorträge, Kreditoren
- `9090` - Summenvortragskonto
- These are system accounts (hidden from normal booking UI)
- Must collectively balance to zero

**Service Classes**:
- `OpeningBalanceCreator` - Creates opening balance entries
- `FiscalYearClosingService` - Closes fiscal year and generates SBK entries
- `BalanceSheetService` - Calculates balance sheets (updated to exclude closing entries and 9000-series accounts)
- `GuVService` - Calculates Profit & Loss statements using SKR03 Gesamtkostenverfahren

#### Balance Sheet Generation
The `BalanceSheetService` generates balance sheets from posted journal entries:
- **SKR03 Code Range Mapping**: Accounts are automatically grouped based on their code prefix:
  - 0xxx → Anlagevermögen (Fixed Assets)
  - 1xxx → Umlaufvermögen (Current Assets)
  - 2xxx → Eigenkapital (Equity)
  - 3xxx → Fremdkapital (Liabilities)
  - 9xxx → Closing accounts (filtered out from display)
- **Closing Entry Exclusion**: Entries with `entry_type: 'closing'` are excluded from calculations
- **Posted Entries Only**: Only posted journal entries are included (GoBD compliance)
- **Net Income Integration**: P&L is calculated from revenue (4xxx) and expense (5xxx-7xxx) accounts and included in equity
- **GuV Integration**: Automatically calls `GuVService` to calculate detailed GuV data alongside balance sheet
- **Account Balances**: Calculated using debit/credit logic appropriate to each account type
- **Balance Verification**: Ensures Aktiva = Passiva (or flags data integrity issues)
- **Stored Balance Sheets**: For closed fiscal years, loads stored balance sheet instead of recalculating
- **Backward Compatibility**: Older balance sheets without GuV data will have GuV calculated on-the-fly

#### GuV (Gewinn- und Verlustrechnung) Generation
The `GuVService` generates Profit & Loss statements following German accounting standards:
- **Gesamtkostenverfahren Format**: Implements § 275 Abs. 2 HGB (Total Cost Method)
- **SKR03 Account Grouping**: Automatically categorizes accounts into GuV sections:
  - **1. Umsatzerlöse** (Revenue) - 4xxx accounts
  - **2. Materialaufwand** (Material expense) - 5xxx accounts
  - **3. Personalaufwand** (Personnel expense) - 6xxx accounts
  - **4. Abschreibungen** (Depreciation) - 76xx accounts
  - **5. Sonstige betriebliche Aufwendungen** (Other operating expenses) - 70xx-75xx, 77xx-79xx accounts
- **Net Income Calculation**: Calculates Jahresüberschuss (profit) or Jahresfehlbetrag (loss)
- **Exclusion Rules**: Excludes closing entries and 9xxx accounts (same as balance sheet)
- **Posted Entries Only**: Only posted journal entries are included (GoBD compliance)
- **Section Subtotals**: Each GuV section includes accounts list and subtotal
- **Display Type Hints**: Sections tagged as positive (revenue) or negative (expenses) for UI formatting
- **Automatic Persistence**: GuV data stored in `balance_sheets.data` JSONB field when closing fiscal years

## Development Commands

### Running Commands
This project runs in a devcontainer. Use the `./dc` helper script to execute commands inside the container.

The `./dc` script is a shorthand for `devcontainer exec --workspace-folder .`

Examples:
```bash
# Rails console
./dc rails console

# Database migrations
./dc rails db:migrate

# Run tests
./dc rspec .

# Apply linting rules
./dc rubocop -A

# Start Rails server (if not already running)
./dc rails server
```

You can also use the full command if needed:
```bash
devcontainer exec --workspace-folder . rails console
```

### Common Tasks

#### Database
```bash
# Create database
./dc rails db:create

# Run migrations
./dc rails db:migrate

# Rollback migration
./dc rails db:rollback

# Reset database (caution: destroys all data)
./dc rails db:reset

# Seed database
./dc rails db:seed
```

#### Frontend (Vite)
```bash
# The Vite dev server typically runs automatically in the devcontainer
# Check package.json for available scripts

# Install JavaScript dependencies
./dc npm install

# Check for TypeScript errors
./dc npm run check
```

Explicitly building the frontend assets is not necessary, as there is
usually a Vite process running during development.


#### Generators
```bash
# Generate model
./dc rails generate model ModelName

# Generate controller
./dc rails generate controller ControllerName

# Generate migration
./dc rails generate migration MigrationName
```

## Project Structure

```
.
├── app/
│   ├── controllers/          # Rails controllers (Inertia endpoints)
│   │   ├── fiscal_years_controller.rb        # Fiscal year management
│   │   ├── opening_balances_controller.rb    # Opening balance entry
│   │   └── reports/                          # Report controllers
│   │       └── balance_sheets_controller.rb  # Balance sheet reports
│   ├── models/              # ActiveRecord models
│   │   ├── balance_sheet.rb            # Stored balance sheets (opening/closing)
│   │   ├── fiscal_year.rb              # Fiscal years with workflow states
│   │   ├── journal_entry.rb            # Journal entries with entry_type
│   │   ├── account.rb                  # Chart of accounts
│   │   └── account_template.rb         # Account templates for charts
│   ├── services/            # Service classes (business logic)
│   │   ├── balance_sheet_service.rb         # Balance sheet calculation (integrates GuV)
│   │   ├── guv_service.rb                   # GuV (P&L) calculation using Gesamtkostenverfahren
│   │   ├── opening_balance_creator.rb       # Opening balance (EBK) creation
│   │   ├── fiscal_year_closing_service.rb   # Fiscal year closing (SBK)
│   │   ├── journal_entry_creator.rb         # Journal entry creation
│   │   └── journal_entry_destroyer.rb       # Journal entry deletion
│   ├── frontend/            # React + TypeScript frontend
│   │   ├── components/      # React components (including shadcn/ui)
│   │   │   ├── FiscalYearStatusBadge.tsx  # Workflow state indicator
│   │   │   ├── reports/                   # Report-specific components
│   │   │   │   ├── BalanceSheetSection.tsx  # Reusable balance sheet section display
│   │   │   │   └── GuVSection.tsx           # GuV display component
│   │   │   └── ui/                        # shadcn/ui components
│   │   ├── pages/          # Inertia page components
│   │   │   ├── FiscalYears/              # Fiscal year management
│   │   │   │   ├── Index.tsx             # List fiscal years
│   │   │   │   ├── Show.tsx              # Fiscal year details
│   │   │   │   └── PreviewClosing.tsx    # Preview closing balance
│   │   │   ├── OpeningBalances/
│   │   │   │   └── Form.tsx              # Opening balance entry form
│   │   │   ├── Reports/                  # Report pages
│   │   │   │   └── BalanceSheet.tsx      # Balance sheet & GuV report
│   │   │   ├── BankAccounts/
│   │   │   └── Dashboard/
│   │   ├── types/          # TypeScript type definitions
│   │   │   └── accounting.ts             # Shared accounting types (BalanceSheetData, GuVData, etc.)
│   │   └── utils/          # Shared utility functions (formatting, etc.)
│   └── views/              # Minimal (Inertia uses React for views)
├── db/
│   ├── migrate/            # Database migrations
│   └── schema.rb           # Current database schema
├── config/
│   ├── routes.rb           # Route definitions
│   └── database.yml        # Database configuration
└── .devcontainer/          # Dev container configuration
```

## Frontend Development

### Formatting Utilities

The application uses shared formatting utilities to ensure consistent display of dates, currencies, and amounts across all components.

**Location**: `app/frontend/utils/formatting.ts`

**Available Functions**:
- `formatDate(dateString, options?)` - Formats dates to German locale (DD.MM.YYYY)
- `formatAmount(amount, currency)` - Formats amounts with currency symbols (e.g., "1.234,56 €")
- `formatCurrency(amount, currency?)` - Like formatAmount but handles null values (returns '-')

**Usage**:
```typescript
import { formatDate, formatAmount, formatCurrency } from '@/utils/formatting'

// Format a date
formatDate('2024-03-15')  // Returns: "15.03.2024"

// Format an amount with currency
formatAmount(1234.56, 'EUR')  // Returns: "1.234,56 €"

// Format currency with null handling
formatCurrency(null)  // Returns: "-"
formatCurrency(100.50)  // Returns: "100,50 €"
```

**Important**:
- **Before creating new formatting functions**, always check if the functionality exists in `formatting.ts`
- **All new formatting utilities** should be added to `formatting.ts` to avoid duplication
- Use German locale (`de-DE`) for all date and number formatting to comply with local accounting standards

### TypeScript Types

The application uses centralized TypeScript type definitions for accounting data structures.

**Location**: `app/frontend/types/accounting.ts`

**Available Types**:
- `AccountBalance` - Account with code, name, and balance (shared across components)
- `FiscalYear` - Fiscal year with workflow state and metadata
- `BalanceSheetData` - Complete balance sheet data structure including GuV
- `GuVData` - GuV (P&L) data structure
- `GuVSection` - Individual GuV section with accounts and subtotal

**Usage**:
```typescript
import { BalanceSheetData, GuVData, AccountBalance } from '@/types/accounting'

// Use in component props
interface MyComponentProps {
  balanceSheet: BalanceSheetData
}

// Access GuV data
const guv: GuVData | undefined = balanceSheet.guv
```

**Important**:
- **All accounting-related types** should be defined in `accounting.ts`
- **Import types from this central location** to ensure consistency
- **GuV data is optional** in `BalanceSheetData` for backward compatibility with older balance sheets

## Data Models

### Journal Entry Workflow

1. **Create Journal Entry** (draft state)
   - Set company, fiscal year, booking date, description
   - Optionally attach a document (receipt/invoice)

2. **Add Line Items**
   - Each line item references an account
   - Specify amount and direction (debit/credit)
   - Optionally link to bank transaction
   - System validates that debits = credits

3. **Post Journal Entry**
   - Call `journal_entry.post!`
   - Sets `posted_at` timestamp
   - Entry becomes immutable (GoBD compliance)

### Example: Split Booking

Office supplies purchase for €119 (€100 + €19 VAT):

```ruby
# Create journal entry
je = JournalEntry.create!(
  company: company,
  fiscal_year: fiscal_year_2025,
  booking_date: Date.today,
  description: "Office supplies from Supplier XYZ"
)

# Line item 1: Credit bank account (money out)
LineItem.create!(
  journal_entry: je,
  account: bank_account,           # Account "1200 Bank"
  amount: 119.00,
  direction: "credit",
  bank_transaction: bank_tx        # Link to actual bank transaction
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

# Post the entry (make immutable)
je.post!
```

### Balance Sheet Report

The Balance Sheet (Bilanz) report provides a snapshot of the company's financial position at the end of a fiscal year.

**Access**: Navigate to Reports → Balance Sheet in the sidebar menu.

**Features**:
- **Fiscal Year Selection**: Choose any fiscal year from the dropdown to view its balance sheet
- **Two-Column Layout**:
  - **Aktiva (Assets)**: Fixed Assets (Anlagevermögen) and Current Assets (Umlaufvermögen)
  - **Passiva (Liabilities & Equity)**: Equity (Eigenkapital) with net income/loss, and Liabilities (Fremdkapital)
- **Automatic P&L Integration**: Net income (Jahresüberschuss) or loss (Jahresfehlbetrag) is calculated and included in equity
- **GuV Display**: Detailed Profit & Loss statement displayed below balance sheet using Gesamtkostenverfahren format
- **Balance Verification**: System verifies that Aktiva = Passiva and warns of data integrity issues
- **Status Indicators**: Shows whether fiscal year is open or closed
- **German Locale Formatting**: Amounts displayed in EUR with German number formatting
- **Modular Components**: Uses extracted `BalanceSheetSection` and `GuVSection` components for clean, maintainable code

**How It Works**:
1. Service queries all journal entries for the selected fiscal year
2. Only posted entries are included (GoBD compliance)
3. Line items are aggregated by account using SQL GROUP BY
4. Accounts are automatically grouped by SKR03 code ranges (0xxx, 1xxx, 2xxx, 3xxx)
5. Net income is calculated from revenue (4xxx) minus expenses (5xxx-7xxx)
6. GuVService calculates detailed GuV breakdown with section-wise grouping
7. Zero-balance accounts are filtered out for cleaner reports
8. Final balance sheet is validated (Aktiva = Passiva)

**Implementation**:
- **Services**:
  - `BalanceSheetService` (`app/services/balance_sheet_service.rb`) - Main service
  - `GuVService` (`app/services/guv_service.rb`) - GuV calculation
- **Controller**: `Reports::BalanceSheetsController` (`app/controllers/reports/balance_sheets_controller.rb`)
- **Frontend**:
  - `Reports/BalanceSheet.tsx` (`app/frontend/pages/Reports/BalanceSheet.tsx`) - Main page
  - `reports/BalanceSheetSection.tsx` (`app/frontend/components/reports/BalanceSheetSection.tsx`) - Balance sheet display
  - `reports/GuVSection.tsx` (`app/frontend/components/reports/GuVSection.tsx`) - GuV display
- **Types**: `accounting.ts` (`app/frontend/types/accounting.ts`) - Shared TypeScript interfaces
- **Route**: `/reports/balance_sheet`

### GuV (Gewinn- und Verlustrechnung) Report

The GuV report provides a detailed breakdown of income and expenses following German accounting standards.

**Access**: The GuV is automatically displayed below the balance sheet when viewing balance sheet reports.

**Features**:
- **Gesamtkostenverfahren Format**: Follows § 275 Abs. 2 HGB (Total Cost Method)
- **Five Main Sections**: Revenue, Material Expense, Personnel Expense, Depreciation, Other Operating Expenses
- **Account Details**: Shows individual accounts within each section with amounts
- **Section Subtotals**: Displays subtotals for each GuV section
- **Net Income/Loss**: Final result labeled as Jahresüberschuss (profit) or Jahresfehlbetrag (loss)
- **Color Coding**: Expense sections displayed in red for visual clarity
- **German Standards**: Complies with HGB § 275 Abs. 2 requirements
- **Automatic Calculation**: Calculated on-the-fly for open fiscal years
- **Persistent Storage**: Stored in balance sheet data when fiscal year is closed
- **Backward Compatible**: Older balance sheets calculate GuV on-the-fly if not stored

**How It Works**:
1. `GuVService` queries posted journal entries for the fiscal year
2. Accounts are grouped by SKR03 code ranges into GuV sections:
   - 4xxx → Umsatzerlöse (Revenue)
   - 5xxx → Materialaufwand (Material Expense)
   - 6xxx → Personalaufwand (Personnel Expense)
   - 76xx → Abschreibungen (Depreciation)
   - 70xx-75xx, 77xx-79xx → Sonstige betriebliche Aufwendungen (Other Expenses)
3. Each section calculates a subtotal
4. Net income is calculated as sum of all section subtotals
5. GuV data is included in balance sheet response
6. Frontend displays GuV below balance sheet in scrollable layout

**Implementation**:
- **Service**: `GuVService` (`app/services/guv_service.rb`)
- **Frontend Component**: `reports/GuVSection.tsx` (`app/frontend/components/reports/GuVSection.tsx`)
- **Types**: `GuVData`, `GuVSection` in `accounting.ts`
- **Storage**: Stored in `balance_sheets.data` JSONB field under `guv` key
- **Tests**: Comprehensive test suite in `spec/services/guv_service_spec.rb`

## Fiscal Year Management

### Fiscal Year Workflow

The application supports a complete fiscal year lifecycle with proper opening and closing procedures following German accounting standards.

**Access**: Navigate to `/fiscal_years` to manage fiscal years.

**Workflow States**:

1. **Open** - Newly created fiscal year without opening balance
   - Cannot create journal entries yet
   - Shows "Create Opening Balance" button

2. **Open with Opening** - Opening balance has been posted
   - Normal journal entries can be created
   - This is the active working state for the fiscal year

3. **Closed** - Fiscal year has been finalized
   - Closing balance sheet stored
   - All entries are immutable
   - Opening balance automatically created for next year

**Creating Opening Balance**:
- Navigate to fiscal year details → "Create Opening Balance"
- Two options:
  - **Import from Previous Year** (recommended): Automatically imports closing balance
  - **Manual Entry**: Enter balance sheet data manually (for first year or corrections)
- Opening balance must be posted before journal entries can be created

**Closing Fiscal Year**:
1. Navigate to fiscal year details → "Preview Closing"
2. Review the calculated closing balance sheet and GuV
3. System validates that Aktiva = Passiva
4. Click "Confirm Close Fiscal Year"
5. System automatically:
   - Creates SBK (closing) journal entries
   - Stores closing balance sheet with GuV data
   - Marks fiscal year as closed
   - Creates opening balance for next fiscal year

**Controllers and Routes**:
- `FiscalYearsController`:
  - `GET /fiscal_years` - List all fiscal years
  - `GET /fiscal_years/:id` - Show fiscal year details
  - `GET /fiscal_years/:id/preview_closing` - Preview closing balance
  - `POST /fiscal_years/:id/close` - Close the fiscal year
- `OpeningBalancesController`:
  - `GET /opening_balances/new` - Opening balance entry form
  - `POST /opening_balances` - Create opening balance

**Frontend Pages**:
- `FiscalYears/Index.tsx` - List fiscal years with workflow state badges
- `FiscalYears/Show.tsx` - Fiscal year details with workflow timeline
- `FiscalYears/PreviewClosing.tsx` - Preview closing balance before finalizing
- `OpeningBalances/Form.tsx` - Create opening balance (manual or carryforward)
- `FiscalYearStatusBadge.tsx` - Component showing workflow state with icons

## German Accounting Context

### Chart of Accounts (Kontenrahmen)
The application should support standard German charts of accounts:
- **SKR03** - Process-oriented (most common)
- **SKR04** - Balance sheet-oriented

Account codes follow the standard numbering:
- 0xxx: Asset accounts (Anlagevermögen)
- 1xxx: Current assets (Umlaufvermögen)
- 2xxx: Equity (Eigenkapital)
- 3xxx: Liabilities (Fremdkapital)
- 4xxx: Operating income (Betriebliche Erträge)
- 5-7xxx: Operating expenses (Betriebliche Aufwendungen)
- 8xxx: Revenue accounts (Erlöskonten)
- 9xxx: Carryforward and closing accounts (Saldenvorträge - EBK/SBK)

### VAT Rates (Umsatzsteuer)
Common German VAT rates to support:
- 19% standard rate (Regelsteuersatz)
- 7% reduced rate (ermäßigter Steuersatz)
- 0% tax-free (steuerfrei)

### VAT Accounting Method
The application currently supports **Ist-Versteuerung** (cash accounting):
- VAT becomes due/deductible when payment is received/made
- This is the method used when booking bank transactions directly
- Soll-Versteuerung (accrual accounting) would require invoice-based VAT handling

### Tax Reports
- **UStVA** (Umsatzsteuervoranmeldung) - Monthly or quarterly VAT pre-registration
- **Annual Tax Return** - Yearly submission
- **ELSTER Integration** - Electronic tax filing system (future consideration)

## Security & Compliance

### Data Protection
- User authentication via Devise
- Company data isolation (users only access their companies)
- Role-based access through CompanyMembership

### GoBD Compliance
- Posted journal entries are immutable (via `posted_at` timestamp)
- Posted balance sheets are immutable (via `posted_at` timestamp)
- Complete audit trail through timestamps and workflow state tracking
- Document archival (receipts/invoices stored with metadata)
- Fiscal year closing mechanism with SBK entries
- 10-year retention of closed fiscal years and balance sheets
- Proper separation of opening/closing entries from regular transactions

## Future Considerations

- **DATEV Export** - Export accounting data in DATEV format
- **ELSTER Integration** - Direct electronic tax filing
- **Bank API Integration** - FinTS/HBCI or PSD2 for automatic bank sync
- **OCR for Receipts** - Automatic extraction of invoice data
- **Multi-currency Support** - Currently focuses on EUR
- **Additional Reports** - Cash Flow Statement, expanded GuV sections
- **Document Management** - Enhanced DMS with full-text search

## Getting Started

1. Ensure the devcontainer is running
2. Run migrations: `./dc rails db:migrate`
3. Seed initial data (if available): `./dc rails db:seed`
4. Access the application (typically at http://localhost:3000)
5. Create your first company and chart of accounts
6. Start booking transactions!

## Notes for Claude Code

When working on this project:
- Use the `./dc` helper script for all Rails/npm commands (e.g., `./dc rails console`)
- Alternatively, use the full form: `devcontainer exec --workspace-folder . <command>`
- Respect GoBD immutability rules when modifying accounting logic
- Consider German accounting standards (SKR03/04) when creating account-related features
- Use Inertia.js for routing between backend and React frontend
- Follow TypeScript best practices for frontend code
- Use shadcn/ui components for consistent UI design
- **Always check `app/frontend/utils/formatting.ts` for existing formatting functions before creating new ones**
- **Add all new formatting utilities to `formatting.ts` to maintain consistency and avoid duplication**
- **Import accounting types from `app/frontend/types/accounting.ts`** instead of defining them locally
- **Extract reusable components** to `app/frontend/components/` for better code organization
- When adding GuV acronyms or similar, update `config/initializers/inflections.rb` to ensure Rails recognizes them correctly
