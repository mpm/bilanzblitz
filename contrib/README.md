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

### Generate Category Mapping (Recommended Workflow)

The recommended workflow uses a three-stage process that allows manual review and correction of mappings:

#### 1. Generate Intermediate Mapping

Run `ruby generate_category_mapping.rb` to create the intermediate mapping file.

This script:
- Reads the official HGB structure from `bilanz-aktiva.json`, `bilanz-passiva.json`, and `guv.json`
- Reads SKR03 categories from `skr03-ocr-results.json`
- Performs fuzzy matching between HGB and SKR03 category names
- Generates hierarchical category IDs (e.g., `aktiva.anlagevermoegen.immaterielle.geschaeftswert`)
- Creates `category-mapping.yml` - a human-editable YAML file

**Important**: The script reports TWO types of unmatched categories:
1. **HGB categories without SKR03 matches**: Categories in the official structure that couldn't be matched to any SKR03 category
2. **SKR03 categories not used**: SKR03 categories that weren't assigned to any HGB position (listed at the end of the YAML file)

The second type is critical - these SKR03 categories contain accounts that won't appear in your balance sheet or GuV unless manually assigned!

**Example output**:
```
HGB Categories Statistics:
  Total HGB categories: 94
  Auto-matched: 52
  Calculated: 28
  Unmatched HGB categories (needs review): 4

SKR03 Categories Statistics:
  Total SKR03 categories: 123
  Used in mapping: 50
  Unmatched SKR03 categories: 73

⚠️  WARNING: 73 SKR03 categories were not matched!
   These accounts will be missing from your balance sheet/GuV.
   See the end of category-mapping.yml for the full list.
```

#### 2. Review and Edit Mapping

Open `category-mapping.yml` and:
1. Check the auto-matched categories (marked `match_status: auto`)
2. Review unmatched HGB categories (marked `match_status: none`)
3. **Important**: Check the end of the file for unmatched SKR03 categories
4. Manually assign SKR03 categories to appropriate HGB positions
5. Change `match_status: auto` to `match_status: manual` for manual corrections

**Example mapping entry**:
```yaml
aktiva:
  anlagevermoegen:
    immaterielle_vermoegensgegenstaende:
      geschaeftswert:
        name: "Geschäfts- oder Firmenwert"
        match_status: auto
        skr03_category: "Geschäfts- oder Firmenwert"
        notes: ""
```

To fix an unmatched SKR03 category, find the appropriate HGB category and update its `skr03_category` field.

#### 3. Generate Presentation Rules Mapping

Run `ruby generate_presentation_rules.rb` to detect saldo-dependent accounts.

This script:
- Analyzes SKR03 categories for saldo patterns ("H-Saldo", "S-Saldo", "oder")
- Detects bidirectional accounts (e.g., "Forderungen aus L&L H-Saldo oder sonstige Verbindlichkeiten S-Saldo")
- Infers default presentation rules from category names
- Creates `presentation-rules-mapping.yml` - a human-editable YAML file

**Key Concept**: Some accounts can appear on either side of the balance sheet depending on their balance direction:
- Debit balance (S-Saldo) → typically Aktiva
- Credit balance (H-Saldo) → typically Passiva

**Important**: Review the generated `presentation-rules-mapping.yml` file:
1. Check auto-detected bidirectional rules (marked `status: auto`)
2. Verify inferred default rules (marked `status: inferred`)
3. Manually assign rules to unknown categories (marked `status: unknown`)
4. Fix any incorrect detections (marked `status: needs_review`)

#### 4. Build Final JSON Files

Run `ruby build_category_json.rb` to generate the final output files.

This script:
- Reads the validated `category-mapping.yml`
- Reads the validated `presentation-rules-mapping.yml` (if available)
- Reads account codes from `skr03-ocr-results.json`
- Generates `bilanz-with-categories.json` with all account codes properly mapped
- Generates `guv-with-categories.json` with all account codes properly mapped
- Generates `skr03-accounts.csv` with hierarchical category IDs and presentation rules

The generated files use hierarchical category IDs (e.g., `b.aktiva.anlagevermoegen.sachanlagen`) for human-readable category identification.

### Alternative: Legacy Single-Step Approach

**Deprecated**: The script `parse_chart_of_accounts.rb` provides a legacy single-step approach but is **not recommended** because it performs fuzzy matching without manual review, provides no visibility into unmatched SKR03 categories, and offers no opportunity to correct matching errors.

Use the three-stage workflow (generate category mapping → generate presentation rules → review → build) instead.

## Output Files

The recommended three-stage workflow (`generate_category_mapping.rb` → `generate_presentation_rules.rb` → `build_category_json.rb`) generates the following files:

### Generated Files

### 0. Intermediate Files (Human-Editable)

#### category-mapping.yml

**Purpose**: Human-editable intermediate mapping that allows manual review and correction before generating final JSON files.

**Generated by**: `generate_category_mapping.rb`
**Used by**: `build_category_json.rb`

**Structure**:
```yaml
aktiva:
  anlagevermoegen:
    _meta:
      name: "Anlagevermögen"
      match_status: calculated
      skr03_category: null
      notes: "Parent category - sum of children"
    immaterielle_vermoegensgegenstaende:
      geschaeftswert:
        name: "Geschäfts- oder Firmenwert"
        match_status: auto
        skr03_category: "Geschäfts- oder Firmenwert"
        notes: ""
```

**Important Section**: At the end of the file, you'll find a commented list of all SKR03 categories that were NOT matched to any HGB category:

```yaml
# ==============================================================================
# UNMATCHED SKR03 CATEGORIES
# ==============================================================================
#
# - Kassenbestand, Bundesbankguthaben, Guthaben bei Kreditinstituten...
# - Rechnungsabgrenzungsposten (Aktiva)
# - ... (and many more)
```

These unmatched SKR03 categories are critical to review - they contain accounts that won't appear in your reports unless manually assigned!

#### presentation-rules-mapping.yml

**Purpose**: Human-editable mapping of SKR03 categories to presentation rules for saldo-dependent accounts.

**Generated by**: `generate_presentation_rules.rb`
**Used by**: `build_category_json.rb`

**Structure**:
```yaml
rules:
  fll_standard:
    name: "Forderungen L&L Standard"
    debit_cid: "b.aktiva.umlaufvermoegen.forderungen_und_sonstige_vermoegensgegenstaende.forderungen_aus_lieferungen_und_leistungen"
    credit_cid: "b.passiva.verbindlichkeiten.sonstige_verbindlichkeiten_davon_aus_steuern_davon_im_rahmen"

categories:
  "Forderungen aus Lieferungen und Leistungen H-Saldo oder sonstige Verbindlichkeiten S-Saldo":
    detected_rule: fll_standard
    confidence: high
    reason: "Pattern: 'X H-Saldo oder Y S-Saldo'"
    accounts: ["1499"]
    status: auto
```

**Important**: Review and verify all detected rules before running `build_category_json.rb`.

### 1. Final Output Files

#### skr03-accounts.csv

A CSV file containing all SKR03 account codes with their descriptions, category associations, and presentation rules.

**Generated by**: `build_category_json.rb`

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
- `cid`: Hierarchical category ID (e.g., "b.aktiva.anlagevermoegen.sachanlagen")
- `presentation_rule`: Presentation rule identifier (e.g., "fll_standard", "asset_only")
- `description`: Human-readable description of the account

#### bilanz-with-categories.json

A structured JSON file mapping the German balance sheet (Bilanz) structure to SKR03 account codes.

**Generated by**: `build_category_json.rb`

**Structure**:
```json
{
  "aktiva": {
    "Anlagevermögen": {
      "cid": null,
      "matched_category": null,
      "codes": [],
      "items": [
        {
          "name": "Immaterielle Vermögensgegenstände",
          "cid": null,
          "matched_category": null,
          "codes": [],
          "children": [
            {
              "name": "Selbst geschaffene gewerbliche Schutzrechte...",
              "cid": "9f184e6",
              "matched_category": "Selbst geschaffene gewerbliche Schutzrechte...",
              "codes": ["0043", "0044", "0045", "0046", "0047", "0048"]
            }
          ]
        }
      ]
    }
  },
  "passiva": {
    "Eigenkapital": { ... },
    "Rückstellungen": { ... },
    "Verbindlichkeiten": { ... }
  }
}
```

**Key Attributes**:
- `cid`: Hierarchical category identifier (e.g., "b.aktiva.anlagevermoegen.sachanlagen"). Null if no match found.
- `matched_category`: The parsed SKR03 category name that was matched
- `codes`: Array of account codes belonging to this category
- `items`: Sub-categories within a section
- `children`: Detailed positions within an item

#### guv-with-categories.json

A structured JSON file mapping the German Profit & Loss (GuV) structure according to § 275 Abs. 2 HGB (Gesamtkostenverfahren) to SKR03 account codes.

**Generated by**: `build_category_json.rb`

**Structure**:
```json
{
  "Umsatzerlöse": {
    "cid": "guv.umsatzerloese",
    "matched_category": "Umsatzerlöse",
    "codes": ["2750", "2751", "8000", "8100", "8120", ...]
  },
  "Materialaufwand": {
    "cid": "guv.materialaufwand",
    "matched_category": null,
    "codes": [],
    "children": [
      {
        "name": "Aufwendungen für Roh-, Hilfs- und Betriebsstoffe...",
        "cid": "guv.materialaufwand.roh_hilfs_betriebsstoffe",
        "matched_category": "Aufwendungen für Roh-, Hilfs- und Betriebsstoffe...",
        "codes": ["3000", "3010", "3020", "3029", ...]
      }
    ]
  }
}
```

**Key Attributes**:
- `cid`: Hierarchical category identifier (e.g., "guv.umsatzerloese"). Null if no match found.
- `matched_category`: The parsed SKR03 category name that was matched
- `codes`: Array of account codes belonging to this category
- `children`: Sub-sections for composite GuV positions (e.g., Materialaufwand has subsections for materials and services)

## Using the Output Files

These files are designed to be imported into the BilanzBlitz application to enable:

1. **Automatic Account Categorization**: Map any SKR03 account code to its GuV or balance sheet position
2. **Report Generation**: Generate balance sheets and GuV reports by aggregating accounts according to their categories
3. **Validation**: Ensure posted journal entries use accounts appropriate for their intended purpose

The hierarchical category identifier (`cid`) serves as a stable, human-readable identifier that links:
- Account codes in `skr03-accounts.csv`
- Categories in `bilanz-with-categories.json`
- Categories in `guv-with-categories.json`

**Example hierarchical IDs**:
- `b.aktiva.anlagevermoegen.immaterielle_vermoegensgegenstaende.geschaefts_oder_firmenwert`
- `b.passiva.verbindlichkeiten.verbindlichkeiten_aus_lieferungen_und_leistungen`
- `guv.umsatzerloese`

These IDs make the category structure self-documenting and easy to debug.
