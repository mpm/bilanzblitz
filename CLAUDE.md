# BilanzBlitz - German Accounting Service

## Project Overview

BilanzBlitz is a comprehensive accounting and tax management application designed specifically for German GmbHs (limited liability companies) and UGs (entrepreneurial companies). The application enables businesses to manage their complete accounting workflow, from bank transaction synchronization to annual tax filings.

### Core Features

- **Bank Account Synchronization**: Connect and sync bank accounts to automatically import transactions
- **Receipt & Invoice Management**: Upload and manage receipts, invoices, and other financial documents
- **Double-Entry Bookkeeping**: Complete ledger system with journal entries and line items
- **Transaction Splitting**: Split bank transactions across multiple accounts (e.g., separating VAT from expenses)
- **Bank Reconciliation**: Link bank transactions to bookkeeping entries
- **VAT Reports**: Generate periodic VAT reports (Umsatzsteuervoranmeldung)
- **Annual Tax Returns**: Prepare and generate annual tax filings
- **GoBD Compliance**: Immutable posted entries to comply with German accounting regulations

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
3. **Fiscal Years** - Year-based accounting periods with closing capability
4. **Accounts** - Chart of accounts (SKR03/SKR04 compatible)
5. **Bank Accounts** - Physical bank accounts linked to ledger accounts
6. **Bank Transactions** - Individual transactions from bank feeds (status: pending → booked → reconciled)
7. **Documents** - Scanned receipts, invoices, and supporting documentation
8. **Journal Entries** - Bookkeeping transaction headers (can be posted for immutability)
9. **Line Items** - The debit/credit splits that make up journal entries
10. **Tax Reports** - VAT and annual tax report storage
11. **Account Usages** - Tracks recently used accounts per company for quick selection during booking

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
│   ├── models/              # ActiveRecord models
│   ├── services/            # Service classes (business logic)
│   ├── frontend/            # React + TypeScript frontend
│   │   ├── components/      # React components (including shadcn/ui)
│   │   ├── pages/          # Inertia page components
│   │   └── types/          # TypeScript type definitions
│   └── views/              # Minimal (Inertia uses React for views)
├── db/
│   ├── migrate/            # Database migrations
│   └── schema.rb           # Current database schema
├── config/
│   ├── routes.rb           # Route definitions
│   └── database.yml        # Database configuration
└── .devcontainer/          # Dev container configuration
```

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
- 8xxx: Closing accounts (Abschlusskonten)

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
- Posted journal entries are immutable
- Complete audit trail through timestamps
- Document archival (receipts/invoices stored with metadata)
- Fiscal year closing mechanism

## Future Considerations

- **DATEV Export** - Export accounting data in DATEV format
- **ELSTER Integration** - Direct electronic tax filing
- **Bank API Integration** - FinTS/HBCI or PSD2 for automatic bank sync
- **OCR for Receipts** - Automatic extraction of invoice data
- **Multi-currency Support** - Currently focuses on EUR
- **Reporting Dashboard** - P&L, Balance Sheet, Cash Flow
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
