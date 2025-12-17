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

Run `parse_chart_of_accounts.rb`. Check for almost similarly written
categories and fix spelling in JSON file.

Fix account range artifacts (-09 suffixes at the end of descriptions or
in separate lines (separate items). Also, remove spaces in account
ranges (2000 -99 should become 2000-99). Use regex search in vim for
this (/-\d\d/) to find all number suffixes whether with space or not.

## Output Files

The `parse_chart_of_accounts.rb` script generates three main output files:

### 1. skr03-accounts.csv

A CSV file containing all SKR03 account codes with their descriptions and category associations.

**Format**: `code; flags; range; category; description`

**Example**:
```
4000;;4000-4999;71e9b34;Umsatzerlöse
5000;;5000-5999;70b8f68;Aufwendungen für Roh-, Hilfs- und Betriebsstoffe
```

**Columns**:
- `code`: The account code (e.g., "4000")
- `flags`: Optional flags from the SKR03 PDF (usually empty)
- `range`: Account code range if applicable (e.g., "4000-4999")
- `category`: 7-character hash (cid) identifying the category
- `description`: Human-readable description of the account

### 2. bilanz-with-categories.json

A structured JSON file mapping the German balance sheet (Bilanz) structure to SKR03 account codes.

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
- `cid`: 7-character category hash (null if no match found)
- `matched_category`: The parsed category name that was matched
- `codes`: Array of account codes belonging to this category
- `items`: Sub-categories within a section
- `children`: Detailed positions within an item

### 3. guv-with-categories.json

A structured JSON file mapping the German Profit & Loss (GuV) structure according to § 275 Abs. 2 HGB (Gesamtkostenverfahren) to SKR03 account codes.

**Structure**:
```json
{
  "Umsatzerlöse": {
    "cid": "71e9b34",
    "matched_category": "Umsatzerlöse",
    "codes": ["2750", "2751", "8000", "8100", "8120", ...]
  },
  "Materialaufwand": {
    "cid": null,
    "matched_category": null,
    "codes": [],
    "children": [
      {
        "name": "Aufwendungen für Roh-, Hilfs- und Betriebsstoffe...",
        "cid": "70b8f68",
        "matched_category": "Aufwendungen für Roh-, Hilfs- und Betriebsstoffe...",
        "codes": ["3000", "3010", "3020", "3029", ...]
      }
    ]
  }
}
```

**Key Attributes**:
- `cid`: 7-character category hash (null if no match found)
- `matched_category`: The parsed category name that was matched
- `codes`: Array of account codes belonging to this category
- `children`: Sub-sections for composite GuV positions (e.g., Materialaufwand has subsections for materials and services)

## Using the Output Files

These files are designed to be imported into the BilanzBlitz application to enable:

1. **Automatic Account Categorization**: Map any SKR03 account code to its GuV or balance sheet position
2. **Report Generation**: Generate balance sheets and GuV reports by aggregating accounts according to their categories
3. **Validation**: Ensure posted journal entries use accounts appropriate for their intended purpose

The category hash (`cid`) serves as a stable identifier that links:
- Account codes in `skr03-accounts.csv`
- Categories in `bilanz-with-categories.json`
- Categories in `guv-with-categories.json`
