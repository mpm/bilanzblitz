# BilanzBlitz - German Accounting Service

## Project Overview

BilanzBlitz is a comprehensive accounting and tax management application for German GmbHs and UGs. The application enables businesses to manage their complete accounting workflow, from bank transaction synchronization to annual tax filings.

### Core Features

- **Double-Entry Bookkeeping** - Complete ledger system with journal entries and line items
- **Bank Integration** - Sync bank accounts and automatically import transactions
- **Transaction Splitting** - Split transactions across multiple accounts (VAT, expenses, etc.)
- **Fiscal Year Management** - Complete workflow from opening to closing with state tracking
- **Balance Sheet & GuV Reports** - Generate reports following German GmbH standards (SKR03)
- **Tax Reports** - UStVA (VAT) and KSt (corporate tax) with automatic calculations
- **GoBD Compliance** - Immutable posted entries to comply with German regulations

## Technology Stack

**Backend**: Ruby on Rails 8.1, PostgreSQL, Devise, Inertia Rails
**Frontend**: React, TypeScript, Vite, Tailwind CSS, shadcn/ui
**Development**: Dev Container (Docker)

## Documentation

Detailed documentation is organized into specialized guides:

- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Database schema, design patterns, data integrity rules
- **[ACCOUNTING.md](docs/ACCOUNTING.md)** - German accounting context, SKR03, HGB, GoBD compliance
- **[SERVICES.md](docs/SERVICES.md)** - Service classes (AccountMap, BalanceSheetService, UstvaService, etc.)
- **[FRONTEND.md](docs/FRONTEND.md)** - React components, TypeScript types, formatting utilities
- **[WORKFLOWS.md](docs/WORKFLOWS.md)** - Step-by-step user workflows and usage examples

## Quick Start

### Development Commands

This project runs in a devcontainer. Use the `./dc` helper script:

```bash
# Rails console
./dc rails console

# Database migrations
./dc rails db:migrate

# Run tests
./dc rspec .

# Apply linting rules
./dc rubocop -A

# Install JavaScript dependencies
./dc npm install

# Check for TypeScript errors
./dc npm run check
```

The `./dc` script is shorthand for `devcontainer exec --workspace-folder .`

### Getting Started

1. Ensure the devcontainer is running
2. Run migrations: `./dc rails db:migrate`
3. Seed initial data: `./dc rails db:seed`
4. Access the application at http://localhost:3000
5. Create your first company and chart of accounts
6. Start booking transactions!

## Project Structure

```
app/
├── controllers/         # Rails controllers (Inertia endpoints)
│   ├── fiscal_years_controller.rb
│   ├── tax_reports_controller.rb
│   └── reports/
├── models/              # ActiveRecord models
│   ├── journal_entry.rb
│   ├── fiscal_year.rb
│   ├── balance_sheet.rb
│   └── tax_report.rb
├── services/            # Service classes (business logic)
│   ├── account_map.rb
│   ├── balance_sheet_service.rb
│   ├── guv_service.rb
│   ├── ustva_service.rb
│   ├── kst_service.rb
│   └── presentation_rule.rb
├── frontend/            # React + TypeScript
│   ├── components/      # Reusable components
│   ├── pages/           # Inertia pages
│   ├── types/           # TypeScript types
│   └── utils/           # Formatting utilities
└── views/               # Minimal (Inertia uses React)

docs/                    # Detailed documentation
├── ARCHITECTURE.md
├── ACCOUNTING.md
├── SERVICES.md
├── FRONTEND.md
└── WORKFLOWS.md
```

## Key Concepts

### Double-Entry Bookkeeping

Journal entries contain line items with debits and credits that must balance. See [ARCHITECTURE.md](docs/ARCHITECTURE.md) for details.

### GoBD Compliance

Posted journal entries are immutable (cannot be modified or deleted). This ensures audit trail compliance with German tax law.

### Fiscal Year Workflow

Fiscal years progress through states: `open` → `open_with_opening` → `closed`. See [WORKFLOWS.md](docs/WORKFLOWS.md) for the complete lifecycle.

### German Accounting Standards

The application follows SKR03 chart of accounts, HGB balance sheet structure, and § 275 Abs. 2 HGB for GuV. See [ACCOUNTING.md](docs/ACCOUNTING.md) for details.

## Development Guidelines

### Backend Development

- Use service classes for business logic
- Follow GoBD immutability rules for posted entries
- Validate debits = credits in journal entries
- Use `AccountMap` for account categorization
- Use `TaxFormFieldMap` for tax form field definitions

See [SERVICES.md](docs/SERVICES.md) for service class documentation.

### Frontend Development

- Check `app/frontend/utils/formatting.ts` for existing formatting functions
- Import types from `app/frontend/types/` (accounting.ts, tax-reports.ts)
- Extract reusable components to `app/frontend/components/`
- Use German locale (`de-DE`) for dates and numbers
- Follow shadcn/ui component patterns

See [FRONTEND.md](docs/FRONTEND.md) for complete frontend guide.

### Testing

```bash
# Run all specs
./dc rspec .

# Run specific spec file
./dc rspec spec/services/ustva_service_spec.rb
```

### Code Quality

```bash
# Auto-fix Rubocop issues
./dc rubocop -A

# Check TypeScript types
./dc npm run check
```

## Common Tasks

### Database Management

```bash
./dc rails db:create      # Create database
./dc rails db:migrate     # Run migrations
./dc rails db:rollback    # Rollback migration
./dc rails db:reset       # Reset database (destroys all data)
./dc rails db:seed        # Seed database
```

### Generators

```bash
./dc rails generate model ModelName
./dc rails generate controller ControllerName
./dc rails generate migration MigrationName
```

## Security & Compliance

- User authentication via Devise
- Company data isolation (users only access their companies)
- Posted entries are immutable (GoBD compliance)
- 10-year retention of closed fiscal years and balance sheets
- Document archival with metadata

## Future Considerations

- DATEV export (accounting data export format)
- ELSTER integration (electronic tax filing)
- Bank API integration (FinTS/HBCI or PSD2)
- OCR for receipts (automatic invoice data extraction)
- Multi-currency support (currently EUR only)

## Notes for AI Assistants

When working on this project:

- Use `./dc` for all Rails/npm commands
- Respect GoBD immutability rules (posted entries cannot be modified)
- Consider German accounting standards (SKR03, HGB)
- Use Inertia.js for routing (no separate API layer)
- Check existing utilities before creating new ones:
  - Formatting functions: `app/frontend/utils/formatting.ts`
  - TypeScript types: `app/frontend/types/`
  - Service classes: `app/services/`
- Use `AccountMap` service for account **Semantic Category** mapping (don't hardcode ranges)
- Use `PresentationRule` to determine the **Report Section** for accounts based on saldo direction
- Balance sheets support nested **Report Sections** via `AccountMap.build_nested_section()` and `BalanceSheetSection`
- Use `TaxFormFieldMap` service for tax form field definitions
- Import types from centralized locations (`types/accounting.ts`, `types/journal-entries.ts`, `types/tax-reports.ts`)
- Extract reusable components to `app/frontend/components/`
- Journal entries support simplified view (detects VAT patterns automatically) - use `JournalEntryRow` component
- UStVA reports use absolute values (VAT amounts always positive)
- When adding GuV acronyms, update `config/initializers/inflections.rb`

For detailed information, see the specialized documentation in the `docs/` directory.
