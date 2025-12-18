// TypeScript types for tax reports feature

// Tax report summary (for list views)
export interface TaxReportSummary {
  id: number
  reportType: 'ustva' | 'kst' | 'zusammenfassende_meldung' | 'umsatzsteuer' | 'gewerbesteuer'
  reportTypeLabel: string
  periodType: 'monthly' | 'quarterly' | 'annual'
  startDate: string
  endDate: string
  status: 'draft' | 'submitted' | 'accepted'
  submittedAt: string | null
  periodLabel: string
  fiscalYearId?: number
  editable: boolean
  finalized: boolean
}

// Tax form field (individual field in a report)
export interface TaxFormField {
  key: string
  fieldNumber?: number  // For UStVA (e.g., Kennziffer 81, 66)
  name: string
  description?: string
  value: number
  editable: boolean
}

// Tax report section (group of fields with subtotal)
export interface TaxReportSection {
  label: string
  fields: TaxFormField[]
  subtotal: number
}

// Tax adjustment field (for KSt editable adjustments)
export interface TaxAdjustmentField {
  name: string
  description: string
  value: number
  editable: boolean
  adjustmentSign: 'add' | 'subtract'
}

// UStVA report data
export interface UstvaData {
  reportType: 'ustva'
  periodType: 'monthly' | 'quarterly' | 'annual'
  startDate: string
  endDate: string
  fields: TaxFormField[]
  sections: {
    outputVat: TaxReportSection
    inputVat: TaxReportSection
    reverseCharge: TaxReportSection
  }
  netVatLiability: number
  metadata: {
    journalEntriesCount: number
    calculationDate: string
  }
}

// KSt report data
export interface KstData {
  reportType: 'kst'
  fiscalYearId: number
  year: number
  baseData: {
    netIncome: number
    netIncomeLabel: string
    balanceSheetAvailable: boolean
    guvAvailable: boolean
  }
  adjustments: {
    [key: string]: TaxAdjustmentField
  }
  calculated: {
    taxableIncome: number
    kstRate: number
    kstAmount: number
  }
  metadata: {
    calculationDate: string
    storedBalanceSheet: boolean
  }
}

// Union type for all report data
export type TaxReportData = UstvaData | KstData

// Missing period (for missing reports detection)
export interface MissingPeriod {
  label: string
  startDate: string
  endDate: string
}

// Report type configuration
export interface ReportTypeConfig {
  name: string
  description: string
  periodTypes: ('monthly' | 'quarterly' | 'annual')[]
}

// Fiscal year (reused from accounting.ts but defined here for independence)
export interface FiscalYear {
  id: number
  year: number
  startDate: string
  endDate: string
  closed: boolean
}

// Company (minimal interface for tax reports)
export interface Company {
  id: number
  name: string
}
