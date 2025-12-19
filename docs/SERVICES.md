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
```

**Customization**: Edit `GUV_SECTIONS` or `BALANCE_SHEET_CATEGORIES` hashes. Nested structure in `NESTED_BALANCE_SHEET_CATEGORIES`.

**Data Source**:
- `contrib/bilanz-with-categories.json` - Balance sheet mappings
- `contrib/guv-with-categories.json` - GuV mappings
- `contrib/generate_account_map_ranges.rb` - Helper script

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
