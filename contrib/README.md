# About this directory

This directory contains scripts to help import SKR03 documentation and
transform it into data that can be used by BilanzBlitz.

## Overview

The directory contrib-local/ (not in git) contains PDFs that have the
SKR03.

This PDF will be transformed by a series of steps, resulting in a list
of all SKR03 accounts and mapping to the Bilanz and GuV positions.

## Pipeline

### Preparation

You'll need to setup an API key for OpenAI. This will be stored in
`OPENAI_API_KEY` environment variable.

The Ruby scripts here can be run on the developer machine (since the
required imagemagick and poppler-utils are not present in the dev
container). You'll probably need to install the `mini_magick` gem on the
host machine context.

### Run the pipeline steps

1. Run `ruby pdfextract.rb` to convert all PDF pages into images (180dpi).
2. Run `ruby process_pags.rb` to crop and slice the images into a format
   that is suitable for OCR. Actually, every table cell will be converted
   into a separate image, so the OCR doesn't get confused.
   Check the directory (`kontenrahmen-pdf/results`) for valid output and
   remove the last couple of pages (that contain the footnotes and no
   tables.
3. Run `ruby ocr_pages.rb` to submit each result page to OpenAI for
   ocring (the results will be stored in `skr03-ocr-results.json`)

### Treat the result

It is easiest to fix small inconsistencies manually in
skr03-ocr-result.json.

Fix account range artifacts (-09 suffixes at the end of descriptions or
in separate lines (separate items). Also, remove spaces in account
ranges (2000 -99 should become 2000-99). Use regex search in vim for
this (/-\d\d/) to find all number suffixes whether with space or not.

### Map SKR03 account classification to semantic id and report sections

The recommended workflow uses a three-stage process that allows manual review and correction of mappings.

**NEW: Unified CLI Tool** (Recommended)

The SKR03 mapping scripts have been refactored into a unified CLI tool. For convenience, it can be run from the project root using `bin/skr03_mapper`. This provides better code organization, eliminates duplication, and offers a consistent command-line interface.

**Benefits:**
- Unified command interface (like git/rails)
- Easy access via `bin/skr03_mapper` from project root
- Better code organization with proper namespacing (`Contrib::SKR03Mapping::`)
- Eliminated ~245 lines of duplicated code
- Easier to test and maintain
- Backward compatible (old scripts still work as wrappers)

**Quick Start:**
```bash
# Generate category mapping
bin/skr03_mapper generate-mapping

# Generate presentation rules
bin/skr03_mapper generate-rules

# Build final JSON files
bin/skr03_mapper build-json

# Show help
bin/skr03_mapper help
```

#### 1. Generate Intermediate Mapping

Run `bin/skr03_mapper generate-mapping` to create the intermediate mapping file.

This script:
- Reads the official HGB structure from `hgb-bilanz-aktiva.json`, `hgb-bilanz-passiva.json`, and `hgb-guv.json`
- Reads SKR03 account classifications from `skr03-ocr-results.json`
- Performs fuzzy matching between HGB report sections and SKR03 account
  classifications
- Generates Report Section IDs (RSIDs) (e.g., `b.aktiva.anlagevermoegen.immaterielle.geschaeftswert`)
- Creates `skr03-section-mapping.yml` - a human-editable YAML file

**Important**: The script reports TWO types of unmatched classifications:
1. **HGB categories without SKR03 matches**: Categories in the official structure that couldn't be matched to any SKR03 classification
2. **SKR03 classifications not used**: SKR03 classifications that weren't assigned to any HGB position (listed at the end of the YAML file)

The second type is critical - these SKR03 classifications contain accounts that won't appear in your balance sheet or GuV unless manually assigned!

**Example output**:
```
HGB Categories Statistics:
  Total HGB categories: 94
  Auto-matched: 52
  Calculated: 28
  Unmatched HGB categories (needs review): 4

SKR03 Classifications Statistics:
  Total SKR03 classifications: 123
  Used in mapping: 50
  Unmatched SKR03 classifications: 73

⚠️  WARNING: 73 SKR03 classifications were not matched!
   These accounts will be missing from your balance sheet/GuV.
   See the end of skr03-section-mapping.yml for the full list.
```

#### 2. Review and Edit Mapping

Open `skr03-section-mapping.yml` and:
1. Check the auto-matched classifications (marked `match_status: auto`)
2. Review unmatched HGB categories (marked `match_status: none`)
3. **Important**: Check the end of the file for unmatched SKR03 classifications
4. Manually assign SKR03 classifications to appropriate HGB positions
5. Change `match_status: auto` to `match_status: manual` for manual corrections

**Example mapping entry**:
```yaml
aktiva:
  anlagevermoegen:
    immaterielle_vermoegensgegenstaende:
      geschaeftswert:
        name: "Geschäfts- oder Firmenwert"
        match_status: auto
        skr03_classification: "Geschäfts- oder Firmenwert"
        notes: ""
```

To fix an unmatched SKR03 classification, find the appropriate HGB category and update its `skr03_classification` field.

#### 3. Conceptual Decoupling: CID vs. Presentation Rule

BilanzBlitz distinguishes between what an account *is* (Semantic Category) and where it is *placed* (Presentation Rule).

1. **Semantic Category (CID)**: The logical accounting identity of an account (e.g., "Bank account"). This is stored in the `cid` field of an account.
2. **Presentation Rule**: The logic that determines the actual reporting position. For most accounts, the position matches the CID. However, for saldo-dependent accounts (e.g., Bank, Tax, FLL/VLL), the presentation rule might move the account to a different side of the balance sheet.

#### 4. Generate Presentation Rules Mapping

Run `bin/skr03_mapper generate-rules` to detect saldo-dependent accounts.

This script:
- Analyzes SKR03 classifications for saldo patterns ("H-Saldo", "S-Saldo", "oder")
- Detects bidirectional accounts (e.g., "Forderungen aus L&L H-Saldo oder sonstige Verbindlichkeiten S-Saldo")
- Infers default presentation rules from classification names
- Creates `skr03-presentation-rules.yml` - a human-editable YAML file

**Key Concept**: Some accounts can appear on either side of the balance sheet depending on their balance direction:
- Debit balance (S-Saldo) → typically Aktiva
- Credit balance (H-Saldo) → typically Passiva

**Important**: Review the generated `skr03-presentation-rules.yml` file:
1. Check auto-detected bidirectional rules (marked `status: auto`)
2. Verify inferred default rules (marked `status: inferred`)
3. Manually assign rules to unknown classifications (marked `status: unknown`)
4. Fix any incorrect detections (marked `status: needs_review`)

#### 5. Build Final JSON Files

Run `bin/skr03_mapper build-json` to generate the final output files.

This script:
- Reads the validated `skr03-section-mapping.yml`
- Reads the validated `skr03-presentation-rules.yml` (if available)
- Reads account codes from `skr03-ocr-results.json`
- Generates `bilanz-sections-mapping.json` with all account codes properly mapped
- Generates `guv-sections-mapping.json` with all account codes properly mapped
- Generates `skr03-accounts.csv` with semantic category IDs (CIDs) and presentation rules

The generated files use Report Section IDs (RSIDs) (e.g., `b.aktiva.anlagevermoegen.sachanlagen`) for identification.

## Output Files

The recommended three-stage workflow (`bin/skr03_mapper generate-mapping` → `bin/skr03_mapper generate-rules` → `bin/skr03_mapper build-json`) generates the following files:

### Generated Files

### 0. Intermediate Files (Human-Editable)

#### skr03-section-mapping.yml

**Purpose**: Human-editable intermediate mapping that allows manual review and correction before generating final JSON files.

**Generated by**: `bin/skr03_mapper generate-mapping`
**Used by**: `bin/skr03_mapper build-json`

**Important Section**: At the end of the file, you'll find a commented list of all SKR03 classifications that were NOT matched to any HGB category:

```yaml
# ==============================================================================
# UNMATCHED SKR03 CLASSIFICATIONS
# ==============================================================================
#
# - Kassenbestand, Bundesbankguthaben, Guthaben bei Kreditinstituten...
# - Rechnungsabgrenzungsposten (Aktiva)
# - ... (and many more)
```

These unmatched SKR03 classifications are critical to review - they contain accounts that won't appear in your reports unless manually assigned!

#### skr03-presentation-rules.yml

**Purpose**: Human-editable mapping of SKR03 classifications to presentation rules for saldo-dependent accounts.

**Generated by**: `bin/skr03_mapper generate-rules`
**Used by**: `bin/skr03_mapper build-json`

**Important**: Review and verify all detected rules before running `bin/skr03_mapper build-json`.

### 1. Final Output Files

#### skr03-accounts.csv

A CSV file containing all SKR03 account codes with their descriptions, classification associations, and presentation rules.

**Generated by**: `bin/skr03_mapper build-json`

**Format**: `code; flags; range; cid; presentation_rule; description`

**Example**:
```
1499;;;b.aktiva.umlaufvermoegen.forderungen_und_sonstige_vermoegensgegenstaende.forderungen_aus_lieferungen_und_leistungen;fll_standard;Gegenkonto 1451-1497 bei Aufteilung Debitorenkonto
4000;;4000-4999;guv.umsatzerloese;pnl_only;Umsatzerlöse
```

**Columns**:
- `code`: The account code (e.g., "1499")
- `flags`: Optional flags from the SKR03 PDF (usually empty)
- `range`: Account code range if applicable (e.g., "4000-4999")
- `cid`: Semantic category ID (CID) (e.g., "b.aktiva.anlagevermoegen.sachanlagen")
- `presentation_rule`: Presentation rule identifier (e.g., "fll_standard", "asset_only")
- `description`: Human-readable description of the account

#### bilanz-sections-mapping.json

A structured JSON file mapping the German balance sheet (Bilanz) structure to SKR03 account codes.

**Generated by**: `bin/skr03_mapper build-json`

**Key Attributes**:
- `rsid`: Report Section identifier (e.g., "b.aktiva.anlagevermoegen.sachanlagen"). Null if no match found.
- `skr03_classification`: The parsed SKR03 classification name that was matched
- `codes`: Array of account codes belonging to this classification
- `items`: Sub-categories within a section
- `children`: Detailed positions within an item

#### guv-sections-mapping.json

A structured JSON file mapping the German Profit & Loss (GuV) structure according to § 275 Abs. 2 HGB (Gesamtkostenverfahren) to SKR03 account codes.

**Generated by**: `bin/skr03_mapper build-json`

**Key Attributes**:
- `rsid`: Report Section identifier (e.g., "guv.umsatzerloese"). Null if no match found.
- `skr03_classification`: The parsed SKR03 account classification (coming from skr03-ocr-results.json) that was matched
- `codes`: Array of account codes belonging to this classification
- `children`: Sub-sections for composite GuV positions (e.g., Materialaufwand has subsections for materials and services)

## Using the Output Files

These files are designed to be imported into the BilanzBlitz application to enable:

1. **Automatic Account Categorization**: Map any SKR03 account code to its GuV or balance sheet position
2. **Report Generation**: Generate balance sheets and GuV reports by aggregating accounts according to their categories
3. **Validation**: Ensure posted journal entries use accounts appropriate for their intended purpose

The logical identity (CID) serves as a stable, human-readable identifier that links:
- Account codes in `skr03-accounts.csv`
- Categories in `bilanz-sections-mapping.json`
- Categories in `guv-sections-mapping.json`

**Example semantic IDs (CID / default RSID)**:
- `b.aktiva.anlagevermoegen.immaterielle_vermoegensgegenstaende.geschaefts_oder_firmenwert`
- `b.passiva.verbindlichkeiten.verbindlichkeiten_aus_lieferungen_und_leistungen`
- `guv.umsatzerloese`

These IDs make the category structure self-documenting and easy to debug.
