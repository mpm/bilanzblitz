# Frontend Development Guide

## Technology Stack

- **React with TypeScript** - Component-based UI
- **Vite Rails** - Fast frontend build tooling
- **Inertia.js** - SPA experience without building an API
- **Tailwind CSS** - Utility-first CSS framework
- **shadcn/ui** - High-quality, accessible UI components

## Project Structure

```
app/frontend/
├── components/          # Reusable React components
│   ├── ui/             # shadcn/ui components
│   ├── journal-entries/ # Journal entry components
│   ├── reports/        # Report-specific components
│   ├── tax-reports/    # Tax report components
│   └── ...
├── pages/              # Inertia page components
│   ├── FiscalYears/
│   ├── JournalEntries/
│   ├── Reports/
│   ├── TaxReports/
│   └── ...
├── types/              # TypeScript type definitions
│   ├── accounting.ts
│   ├── journal-entries.ts
│   └── tax-reports.ts
└── utils/              # Shared utility functions
    ├── formatting.ts
    └── missing-reports.ts
```

## TypeScript Types

### Centralized Type Definitions

**Location**: `app/frontend/types/`

All shared types should be defined in centralized type files:

**accounting.ts** - Accounting-related types:
- `AccountBalance` - Account with code, name, and balance
- `FiscalYear` - Fiscal year with workflow state
- `BalanceSheetData` - Complete balance sheet structure (includes optional nested structure)
- `BalanceSheetSectionNested` - Nested subcategory tree (optional)
- `GuVData` - GuV (P&L) data structure
- `GuVSection` - Individual GuV section

**journal-entries.ts** - Journal entry types:
- `JournalEntry` - Journal entry with line items
- `LineItem` - Individual debit/credit line item
- `VatPattern` - Detected VAT pattern for simplified display
- `UserConfig` - User preferences including simplified view toggle

**tax-reports.ts** - Tax report types:
- `TaxReportSummary` - Report metadata for list views
- `UstvaData` - Complete UStVA report structure
- `KstData` - Complete KSt report structure
- `TaxFormField` - Individual tax form field
- `TaxReportSection` - Section with fields and subtotal

**Usage**:
```typescript
import { BalanceSheetData, GuVData } from '@/types/accounting'
import { UstvaData, KstData } from '@/types/tax-reports'
```

**Best Practices**:
- Always import types from centralized locations
- Don't define types locally if they're used in multiple places
- Keep types aligned with backend data structures

## Formatting Utilities

**Location**: `app/frontend/utils/formatting.ts`

Shared formatting utilities ensure consistent display across all components.

**Available Functions**:

```typescript
formatDate(dateString: string, options?: Intl.DateTimeFormatOptions)
// Formats dates to German locale (DD.MM.YYYY)

formatAmount(amount: number, currency: string)
// Formats amounts with currency symbols (e.g., "1.234,56 €")

formatCurrency(amount: number | null, currency?: string)
// Like formatAmount but handles null values (returns '-')
```

**Usage**:
```typescript
import { formatDate, formatAmount, formatCurrency } from '@/utils/formatting'

formatDate('2024-03-15')  // "15.03.2024"
formatAmount(1234.56, 'EUR')  // "1.234,56 €"
formatCurrency(null)  // "-"
```

**Important Rules**:
- Always check if formatting function exists before creating new ones
- Add all new formatting utilities to `formatting.ts`
- Use German locale (`de-DE`) for all date and number formatting

## Reusable Components

### ListFilter Component

**Location**: `app/frontend/components/ListFilter.tsx`

Provides filtering, sorting, and search capabilities for list views.

**Features**:
- Fiscal year filter dropdown
- Sort order toggle (ascending/descending)
- Status filter checkbox
- Text search input

**Usage**:
```typescript
import { ListFilter, FilterState } from '@/components/ListFilter'

const [filterState, setFilterState] = useState<FilterState>({
  fiscalYearId: null,
  sortOrder: 'asc',
  hideFilteredStatus: false,
  searchText: ''
})

<ListFilter
  config={{
    showFiscalYearFilter: true,
    showSortOrder: true,
    showStatusFilter: true,
    showTextSearch: true,
    statusFilterLabel: 'Show only pending',
    statusFilterDescription: 'Hiding booked and reconciled transactions',
    searchPlaceholder: 'Search remittance info or counterparty...'
  }}
  fiscalYears={fiscalYears}
  value={filterState}
  onChange={setFilterState}
/>
```

See `app/frontend/pages/BankAccounts/Show.tsx` for complete implementation example.

### Journal Entry Components

**Location**: `app/frontend/components/journal-entries/`

Reusable components for displaying journal entries with intelligent VAT pattern detection. The simplified view automatically detects VAT expenses, VAT revenue, and reverse charge transactions and displays them in a natural language format instead of showing all line items. Users can toggle between simplified and detailed views globally, or expand individual entries.

**Components**:
- `JournalEntryRow` - Main component for rendering a single journal entry
- `SimplifiedView` - Natural language display for detected VAT patterns
- `DetailedView` - Traditional line item table display
- `VatPatternDetector` - Pattern detection logic (VAT expense, revenue, reverse charge)

**Usage**:
```typescript
import { JournalEntryRow } from '@/components/journal-entries/JournalEntryRow'

<JournalEntryRow
  entry={journalEntry}
  index={entryIdx}
  globalSimplifiedMode={simplifiedMode}
  onEdit={handleEdit}
  onDelete={handleDelete}
/>
```

### Report Components

**BalanceSheetSection** (`components/reports/BalanceSheetSection.tsx`):
- Displays balance sheet sections (Aktiva/Passiva)
- Shows accounts with balances
- Calculates section totals

**GuVSection** (`components/reports/GuVSection.tsx`):
- Displays GuV sections with accounts
- Color-codes revenue vs expenses
- Shows subtotals and net income

**Usage**:
```typescript
import { BalanceSheetSection } from '@/components/reports/BalanceSheetSection'
import { GuVSection } from '@/components/reports/GuVSection'
```

### Tax Report Components

**TaxReportSection** (`components/tax-reports/TaxReportSection.tsx`):
- Displays section of tax form fields
- Shows subtotals
- Supports both UStVA and KSt reports

**TaxFormFieldRow** (`components/tax-reports/TaxFormFieldRow.tsx`):
- Individual field row display
- Supports editable and readonly modes
- Shows Kennziffer numbers for UStVA

## Inertia.js Integration

### Page Components

Page components receive props from Rails controllers:

```typescript
interface Props {
  fiscalYears: FiscalYear[]
  balanceSheet: BalanceSheetData
  // ... other props
}

export default function BalanceSheetPage({ fiscalYears, balanceSheet }: Props) {
  // Component logic
}
```

### Data Conversion

- Backend sends snake_case (Ruby conventions)
- Frontend uses camelCase (JavaScript conventions)
- Controllers use `camelize_keys()` helper for Inertia props
- Form submissions use `underscore_keys()` helper

### Navigation

Use Inertia's `router.visit()` or `Link` component:

```typescript
import { router } from '@inertiajs/react'
import { Link } from '@inertiajs/react'

// Programmatic navigation
router.visit(`/fiscal_years/${id}`)

// Link component
<Link href={`/fiscal_years/${id}`}>View Fiscal Year</Link>
```

## User Preferences

### Fiscal Year Preference

**Location**: Stored in `users.config` JSONB column, managed by `UserPreferencesController`

The application maintains a **global fiscal year preference per company** that persists across sessions. This preference is used as the default filter for all views that support fiscal year filtering.

**Storage Format**:
```json
{
  "fiscal_years": {
    "company_id": year  // e.g., "1": 2025
  },
  "ui": {
    "theme": "dark"
  }
}
```

**Backend Implementation**:
- `ApplicationController#preferred_fiscal_year_for_company(company_id)` - Helper method to retrieve preference
- `UserPreferencesController#update` - API endpoint to update preferences
- All controllers that filter by fiscal year should use this preference as the default

**Frontend Implementation**:
- `AppLayout` component displays a global fiscal year selector in the top bar
- Changing the year in the global selector updates the user preference and reloads the page
- User preference is passed via `userConfig` in Inertia shared props

**Views with Fiscal Year Filtering**:

The following views default to the user's preferred fiscal year:

1. **Journal Entries** (`/journal_entries`) - Filters entries by fiscal year
2. **Balance Sheet** (`/reports/balance_sheet`) - Shows balance sheet for selected year
3. **Bank Account Transactions** (`/bank_accounts/:id`) - Filters transactions by fiscal year date range

**Implementation Pattern for New Views**:

When adding a new view that supports fiscal year filtering:

```ruby
# Controller
def index
  @fiscal_years = @company.fiscal_years.order(year: :desc)

  # Use user preference as default
  @fiscal_year = if params[:fiscal_year_id].present?
    @fiscal_years.find_by(id: params[:fiscal_year_id])
  else
    preferred_year = preferred_fiscal_year_for_company(@company.id)
    if preferred_year
      @fiscal_years.find_by(year: preferred_year) || @fiscal_years.first
    else
      @fiscal_years.first
    end
  end

  # Pass selected fiscal year to frontend
  render inertia: "MyPage/Index", props: {
    selectedFiscalYearId: @fiscal_year&.id,
    # ... other props
  }
end
```

```typescript
// Frontend Component
interface Props {
  selectedFiscalYearId: number | null
  // ... other props
}

export default function MyPage({ selectedFiscalYearId }: Props) {
  // Initialize filter with user preference
  const [filterState, setFilterState] = useState({
    fiscalYearId: selectedFiscalYearId,
    // ... other filters
  })

  // Use filterState to filter data
}
```

**Important Notes**:
- The fiscal year preference is stored as a **year number** (e.g., `2025`), not the fiscal year record ID
- This allows the preference to persist even if fiscal year records are recreated
- Each company has its own fiscal year preference to support multi-company access
- The global selector in `AppLayout` automatically syncs with the user's preference

## Component Patterns

### Extract Reusable Components

When functionality is used in multiple places, extract to `components/`:

```typescript
// Before: Inline in multiple pages
// After: Single component in components/ directory
```

### Props Interface

Always define props interfaces:

```typescript
interface MyComponentProps {
  data: BalanceSheetData
  onUpdate: (value: number) => void
}

export function MyComponent({ data, onUpdate }: MyComponentProps) {
  // ...
}
```

### State Management

Use React hooks for local state:

```typescript
const [filterState, setFilterState] = useState<FilterState>({...})
const filteredData = useMemo(() => {
  // Expensive filtering logic
}, [data, filterState])
```

## shadcn/ui Components

The project uses shadcn/ui components for consistent UI:

**Location**: `app/frontend/components/ui/`

**Common Components**:
- Button
- Card
- Dialog
- Select
- Input
- Badge
- Alert

**Usage**:
```typescript
import { Button } from '@/components/ui/button'
import { Card } from '@/components/ui/card'
```

## Best Practices

1. **Check existing utilities** - Before creating new functions, check `utils/` directory
2. **Centralize types** - Import from `types/` directory, don't define locally
3. **Extract components** - Create reusable components in `components/`
4. **Use TypeScript** - Always type props, state, and function parameters
5. **German formatting** - Use German locale (`de-DE`) for dates and numbers
6. **Component composition** - Build complex UIs from smaller, focused components
7. **Performance** - Use `useMemo` and `useCallback` for expensive operations
8. **Accessibility** - Use semantic HTML and ARIA attributes where needed
