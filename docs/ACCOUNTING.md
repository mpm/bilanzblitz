# German Accounting Context

## Data Model & Terminology

To handle the complexity of German accounting (SKR03) and HGB reporting requirements, the application distinguishes between four key concepts:

1. **Account Classification (Kontenbeschriftung)**:
   The raw category description from the chart of accounts (e.g., DATEV SKR03). This is used as the source for initial mapping but is often ambiguous as it can mix semantic meaning with presentation rules.

2. **Semantic Category (Fachliche Kategorie)**:
   The internal logical identity of an account, represented by the `cid` (Category ID, e.g., `b.aktiva.umlaufvermoegen.liquide_mittel`). It defines what the account *is* from an accounting perspective.

3. **Presentation Rule (Bilanzierungsregel)**:
   The logic that determines how an account balance is treated for reporting. While most accounts have a fixed position, bidirectional accounts (e.g., bank accounts) use these rules to switch sides on the balance sheet depending on whether they have a debit or credit balance.

4. **Report Section (Berichtsposition)**:
   A specific node or line item in the official HGB balance sheet (§ 266 HGB) or GuV (§ 275 HGB) structure. This is where the account finally appears in a report. In the code, this is often referred to as **RSID** (Report Section ID).

### Pragmatic Identity of CID and RSID

To keep the data model simple, we use the same identifier format (e.g., `b.aktiva.umlaufvermoegen.liquide_mittel`) for both Semantic Categories (CID) and Report Sections (RSID). 

In the vast majority of cases, an account's CID is identical to its RSID. However, for accounts governed by a **Presentation Rule**, the CID represents the "logical identity" (and acts as a default RSID), while the rule determines the final **RSID** based on the actual account balance at reporting time.

### Data Sources in `contrib/`

The mapping logic is driven by several files in the `contrib/` directory:

- **`hgb-bilanz-aktiva.json`, `hgb-bilanz-passiva.json`, `hgb-guv.json`**: Official HGB reporting structures.
- **`skr03-section-mapping.yml`**: Maps raw SKR03 account classification to HGB Report Sections.
- **`skr03-presentation-rules.yml`**: Defines Bilanzierungsregeln for saldo-dependent accounts.
- **`bilanz-sections-mapping.json`, `guv-sections-mapping.json`**: The final generated mapping files used by `AccountMap` to resolve accounts to their CIDs and Report Sections.

## Chart of Accounts (Kontenrahmen)

The application supports standard German charts of accounts:
- **SKR03** - Process-oriented (most common)

### SKR03 Account Numbering

Account codes follow standard numbering:
- **0xxx**: Asset accounts (Anlagevermögen)
- **1xxx**: Current assets (Umlaufvermögen)
- **2xxx**: Equity (Eigenkapital)
- **3xxx**: Liabilities (Fremdkapital)
- **4xxx**: Operating income (Betriebliche Erträge)
- **5-7xxx**: Operating expenses (Betriebliche Aufwendungen)
- **8xxx**: Revenue accounts (Erlöskonten)
- **9xxx**: Carryforward and closing accounts (Saldenvorträge - EBK/SBK)

## VAT (Umsatzsteuer)

### VAT Rates

Common German VAT rates:
- **19%** - Standard rate (Regelsteuersatz)
- **7%** - Reduced rate (ermäßigter Steuersatz)
- **0%** - Tax-free (steuerfrei)

### VAT Accounting Method

The application currently supports **Ist-Versteuerung** (cash accounting):
- VAT becomes due/deductible when payment is received/made
- This is the method used when booking bank transactions directly
- Soll-Versteuerung (accrual accounting) would require invoice-based VAT handling

### VAT Accounts (SKR03)

Standard VAT accounts:
- **1576** - Abziehbare Vorsteuer 19% (Input VAT 19%)
- **1571** - Abziehbare Vorsteuer 7% (Input VAT 7%)
- **1776** - Umsatzsteuer 19% (Output VAT 19%)
- **1771** - Umsatzsteuer 7% (Output VAT 7%)

## Legal Framework

### HGB (Handelsgesetzbuch) - Commercial Code

**Balance Sheet (§ 266 HGB)**:
- Aktiva (Assets): Anlagevermögen, Umlaufvermögen
- Passiva (Liabilities & Equity): Eigenkapital, Fremdkapital

**GuV (§ 275 Abs. 2 HGB)**:
- Gesamtkostenverfahren (Total Cost Method)
- 17 standardized sections
- Revenue vs. expense structure

### GoBD (Grundsätze zur ordnungsmäßigen Führung und Aufbewahrung von Büchern)

Requirements for proper bookkeeping:
- **Immutability**: Posted entries cannot be modified
- **Completeness**: All transactions must be recorded
- **Traceability**: Audit trail from source document to ledger
- **Retention**: 10-year retention period for tax-relevant documents

## Tax Reports

### UStVA (Umsatzsteuervoranmeldung)

VAT advance return:
- **Frequency**: Monthly, quarterly, or annual
- **Core fields**: Output VAT, Input VAT, Reverse Charge
- **Kennziffer**: Official field numbers (e.g., Kennziffer 81 = Output VAT 19%)
- **Net Liability**: Calculated as Output VAT - Input VAT + Reverse Charge

### KSt (Körperschaftsteuer)

Corporate income tax:
- **Rate**: 15% on taxable income
- **Base**: Net income from GuV (Jahresüberschuss/Jahresfehlbetrag)
- **Adjustments**: Außerbilanzielle Korrekturen (outside-balance-sheet corrections)
  - Non-deductible expenses (add to taxable income)
  - Tax-free income (subtract from taxable income)
  - Loss carryforward (subtract from taxable income)
  - Donations (subtract from taxable income)
  - Special deductions (subtract from taxable income)

### SolZ (Solidaritätszuschlag)

Solidarity surcharge:
- **Rate**: 5.5% of corporate income tax
- **Not yet implemented** in current system

## Balance Sheet Structure (§ 266 HGB)

### Aktiva (Assets)

**A. Anlagevermögen** (Fixed Assets):
- Immaterielle Vermögensgegenstände (Intangible assets)
- Sachanlagen (Tangible assets)
- Finanzanlagen (Financial assets)

**B. Umlaufvermögen** (Current Assets):
- Vorräte (Inventory)
- Forderungen (Receivables)
- Wertpapiere (Securities)
- Kassenbestand (Cash)

### Passiva (Liabilities & Equity)

**A. Eigenkapital** (Equity):
- Gezeichnetes Kapital (Subscribed capital)
- Rücklagen (Reserves)
- Jahresüberschuss/Jahresfehlbetrag (Net income/loss)

**B. Fremdkapital** (Liabilities):
- Rückstellungen (Provisions)
- Verbindlichkeiten (Liabilities)

## GuV Structure (§ 275 Abs. 2 HGB - Gesamtkostenverfahren)

1. Umsatzerlöse (Revenue)
2. Bestandsveränderungen (Change in inventory)
3. Andere aktivierte Eigenleistungen (Capitalized own work)
4. Sonstige betriebliche Erträge (Other operating income)
5. Materialaufwand (Material expenses)
6. Personalaufwand (Personnel expenses)
7. Abschreibungen (Depreciation)
8. Sonstige betriebliche Aufwendungen (Other operating expenses)
9. Erträge aus Beteiligungen (Income from investments)
10. Erträge aus Wertpapieren (Income from securities)
11. Sonstige Zinsen und ähnliche Erträge (Other interest income)
12. Abschreibungen auf Finanzanlagen (Depreciation on financial assets)
13. Zinsen und ähnliche Aufwendungen (Interest expenses)
14. Steuern vom Einkommen und vom Ertrag (Income taxes)
15. Sonstige Steuern (Other taxes)
16. Jahresüberschuss/Jahresfehlbetrag (Net income/loss)

## Terminology

- **EBK** - Eröffnungsbilanzkonto (Opening balance account)
- **SBK** - Schlussbilanzkonto (Closing balance account)
- **Soll** - Debit side of an account
- **Haben** - Credit side of an account
- **Bilanz** - Balance sheet
- **GuV** - Gewinn- und Verlustrechnung (Profit & Loss statement)
- **SKR** - Standardkontenrahmen (Standard chart of accounts)
- **DATEV** - Leading German accounting software provider
- **ELSTER** - Electronic tax filing system
