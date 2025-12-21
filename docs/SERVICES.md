# Service Classes Documentation

## Overview

Service classes encapsulate business logic and complex operations. They follow a consistent pattern with `.call` methods returning result objects.

## Configuration Services

### AccountMap

**Purpose**: Centralized account categorization for GuV sections and balance sheet categories.

**Location**: `app/services/account_map.rb`

**Key Features**:
- Maps SKR03 account codes to GuV sections (§ 275 Abs. 2 HGB)
- Maps SKR03 account codes to balance sheet categories (§ 266 HGB)
- Supports nested balance sheet structure with subcategories
- Determines account types (asset, liability, equity, expense, revenue) from category membership
- Based on official SKR03 documentation
- Single source of truth for account categorization

**Key Methods**:
```ruby
# GuV section methods
AccountMap.section_title(:umsatzerloese)
AccountMap.account_codes(:umsatzerloese)
AccountMap.find_accounts(accounts, :umsatzerloese)

# Balance sheet category methods (flat)
AccountMap.balance_sheet_category_title(:anlagevermoegen)
AccountMap.balance_sheet_account_codes(:anlagevermoegen)
AccountMap.find_balance_sheet_accounts(accounts, :anlagevermoegen)

# Nested balance sheet methods
AccountMap.nested_category_structure(:anlagevermoegen)
AccountMap.category_name(:sachanlagen)  # Works with nested categories
AccountMap.build_nested_section(accounts, :anlagevermoegen)  # Returns BalanceSheetSection tree

# Account type determination
AccountMap.account_type_for_code("0750")  # => "liability"
AccountMap.account_type_for_code("4000")  # => "expense"
```

**Customization**: Edit `GUV_SECTIONS` or `BALANCE_SHEET_CATEGORIES` hashes. Nested structure in `NESTED_BALANCE_SHEET_CATEGORIES`.

**Account Type Determination**:

AccountMap determines account types by looking up the account code in the nested category structure:

1. **Balance sheet accounts**: Determined by whether the account belongs to Aktiva or Passiva
   - Aktiva accounts → `"asset"`
   - Passiva.Eigenkapital → `"equity"`
   - Passiva.Rückstellungen/Verbindlichkeiten → `"liability"`

2. **GuV accounts**: Determined by semantic meaning of the GuV section
   - Revenue sections (Umsatzerlöse, Erträge, etc.) → `"revenue"`
   - Expense sections (Materialaufwand, Personalaufwand, etc.) → `"expense"`

3. **Special accounts**: 9xxx accounts (closing/carryforward) → `"equity"`

This replaces the old range-based approach which was structurally incorrect for SKR03. For example, account 0750 is now correctly classified as `"liability"` (not `"asset"`), because it belongs to the "Verbindlichkeiten" category.

**Data Source**:
- `contrib/bilanz-with-categories.json` - Balance sheet mappings
- `contrib/guv-with-categories.json` - GuV mappings
- `contrib/generate_account_map_ranges.rb` - Helper script

### PresentationRule

**Purpose**: Determines where account balances appear on the balance sheet based on saldo direction (Bilanzierungsregeln).

**Location**: `app/services/presentation_rule.rb`

**Key Concept**: Some accounts can appear on either side of the balance sheet depending on their balance direction. For example:
- Account 1499 (Forderungen L&L): Debit balance → Aktiva, Credit balance → Sonstige Verbindlichkeiten
- Bank accounts: Debit balance → Liquide Mittel, Credit balance → Verbindlichkeiten ggü. Kreditinstituten

**Available Rules**:
- `asset_only` - Always on Aktiva side (e.g., fixed assets, inventory)
- `liability_only` - Always on Passiva side (e.g., provisions)
- `equity_only` - Always in Eigenkapital
- `pnl_only` - P&L accounts (never on balance sheet)
- `fll_standard` - Forderungen aus L&L (saldo-dependent)
- `vll_standard` - Verbindlichkeiten aus L&L (saldo-dependent)
- `bank_bidirectional` - Bank accounts (saldo-dependent)
- `tax_standard` - Tax accounts (saldo-dependent)
- `receivable_affiliated` - Forderungen gg. verbundene Unternehmen (saldo-dependent)
- `payable_affiliated` - Verbindlichkeiten gg. verbundene Unternehmen (saldo-dependent)

**Key Method**:
```ruby
# Apply presentation rule to determine balance sheet position
position = PresentationRule.apply(
  :fll_standard,           # rule identifier
  total_debit: 1500.0,     # total debit amount
  total_credit: 500.0,     # total credit amount
  semantic_cid: "b.aktiva.umlaufvermoegen.forderungen..."  # fallback position
)

# Returns: { cid: "b.aktiva.umlaufvermoegen.forderungen...",
#            balance: 1000.0,
#            side: :aktiva,
#            debit_balance: true }
```

**Integration**:
- `AccountTemplate` and `Account` models have `presentation_rule` field
- `BalanceSheetService` applies presentation rules when calculating account positions
- Rules are assigned during SKR03 import via `contrib/generate_presentation_rules.rb`

**German Terminology**:
- Fachliche Kategorie (Semantic Category) = The account's logical meaning (stored in `cid`)
- Bilanzierungsregel (Presentation Rule) = Rule determining presentation based on saldo

### BalanceSheetSection

**Purpose**: Helper class for nested balance sheet structure with hierarchical subcategories.

**Location**: `app/services/balance_sheet_section.rb`

**Key Features**: Recursive tree structure, flattened_accounts for backward compatibility, own_total vs total calculations

**Usage**: Created via `AccountMap.build_nested_section(accounts, :anlagevermoegen)`

### TaxFormFieldMap

**Purpose**: Centralized tax form field definitions for UStVA and KSt.

**Location**: `app/services/tax_form_field_map.rb`

**Key Features**:
- Defines all UStVA fields (Kennziffer) with calculations
- Defines all KSt fields including adjustments
- Provides section grouping and display order
- Enables easy customization without changing business logic

**Key Methods**:
```ruby
# UStVA methods
TaxFormFieldMap.ustva_fields
TaxFormFieldMap.ustva_field(:kz_81)
TaxFormFieldMap.ustva_fields_by_section
TaxFormFieldMap.ustva_section_label(:output_vat)

# KSt methods
TaxFormFieldMap.kst_fields
TaxFormFieldMap.kst_editable_fields
TaxFormFieldMap.kst_section_label(:adjustments)
```

**Customization**: Edit `USTVA_FIELDS` or `KST_FIELDS` frozen hashes in the service file.

## Report Generation Services

### BalanceSheetService

**Purpose**: Generates balance sheets from posted journal entries.

**Location**: `app/services/balance_sheet_service.rb`

**Key Features**:
- Queries posted journal entries for fiscal year
- Excludes closing entries (`entry_type: 'closing'`)
- Applies `PresentationRule` to determine saldo-dependent account positioning
- Uses `AccountMap` and `BalanceSheetSection` for nested categorization
- Integrates with `GuVService` for net income calculation
- Validates Aktiva = Passiva
- Supports stored balance sheets for closed fiscal years
- Returns flat arrays (backward compatible) plus optional nested structure

**Usage**:
```ruby
service = BalanceSheetService.new(company: company, fiscal_year: fiscal_year)
result = service.call
data = result.data # Contains balance sheet and GuV data
```

### GuVService

**Purpose**: Generates GuV (Profit & Loss) statements using Gesamtkostenverfahren.

**Location**: `app/services/guv_service.rb`

**Key Features**:
- Implements § 275 Abs. 2 HGB format
- Uses `AccountMap` for section categorization
- Excludes closing entries and 9xxx accounts
- Calculates net income (Jahresüberschuss/Jahresfehlbetrag)
- Section subtotals and display hints
- Stored in balance sheets when fiscal year closes

**Usage**:
```ruby
service = GuVService.new(company: company, fiscal_year: fiscal_year)
result = service.call
data = result.data # Contains GuV sections and net income
```

### UstvaService

**Purpose**: Calculates VAT advance returns from posted journal entries.

**Location**: `app/services/ustva_service.rb`

**Key Features**:
- Supports monthly, quarterly, and annual periods
- Aggregates VAT by account using SQL GROUP BY
- Reports all VAT amounts as absolute positive values
- Organizes fields by section (output/input/reverse charge)
- Calculates net VAT liability

**Usage**:
```ruby
service = UstvaService.new(
  company: company,
  start_date: Date.new(2025, 1, 1),
  end_date: Date.new(2025, 1, 31)
)
result = service.call
data = result.data # Contains VAT calculations
```

**Important Notes**:
- VAT amounts use `.abs` to handle asset vs liability accounts
- Only accounts in `Account::VAT_ACCOUNTS` are included
- Formula fields calculated separately from account balances

### KstService

**Purpose**: Calculates corporate income tax with adjustments.

**Location**: `app/services/kst_service.rb`

**Key Features**:
- Gets net income from stored balance sheet or generates on-the-fly
- Five editable adjustment fields (außerbilanzielle Korrekturen)
- 15% corporate tax rate
- Zero floor (tax cannot be negative)
- Distinguishes profit (Jahresüberschuss) from loss (Jahresfehlbetrag)

**Usage**:
```ruby
service = KstService.new(
  company: company,
  fiscal_year: fiscal_year_2025,
  adjustments: {
    nicht_abzugsfaehige_aufwendungen: 2000.00,
    verlustvortrag: 10000.00
  }
)
result = service.call
data = result.data # Contains taxable income and KSt amount
```

**Adjustment Calculation**:
```ruby
taxable_income = net_income
  + nicht_abzugsfaehige_aufwendungen
  - steuerfreie_ertraege
  - verlustvortrag
  - spenden
  - sonderabzuege

kst_amount = [taxable_income * 0.15, 0.0].max
```

## Fiscal Year Services

### OpeningBalanceCreator

**Purpose**: Creates opening balance entries (EBK).

**Location**: `app/services/opening_balance_creator.rb`

**Key Features**:
- Two modes: Manual Entry or Carryforward from previous year
- Uses account 9000 as contra account
- Generates journal entries with `entry_type: 'opening'`
- Stores in `balance_sheets` table with `sheet_type: 'opening'`

### FiscalYearClosingService

**Purpose**: Closes fiscal year and generates closing balance (SBK).

**Location**: `app/services/fiscal_year_closing_service.rb`

**Key Features**:
- Generates SBK journal entries
- Stores closing balance sheet with GuV data
- Marks fiscal year as closed (immutable)
- Creates opening balance for next fiscal year

## Journal Entry Services

### JournalEntryCreator

**Purpose**: Creates journal entries from bank transactions with automatic VAT splits.

**Location**: `app/services/journal_entry_creator.rb`

### JournalEntryDestroyer

**Purpose**: Safely deletes journal entries and resets bank transactions to pending.

**Location**: `app/services/journal_entry_destroyer.rb`

## Service Patterns

### Result Objects

Services return result objects with:
```ruby
result.success?  # Boolean
result.data      # Hash with results
result.errors    # Array of error messages
```

### Validation

Services validate parameters before execution and return descriptive error messages.

### Database Transactions

Complex operations use database transactions to ensure consistency.

### Error Handling

Services handle errors gracefully and provide useful error messages to controllers.
