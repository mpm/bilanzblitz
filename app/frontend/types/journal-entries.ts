export interface LineItem {
  id: number
  accountCode: string
  accountName: string
  amount: number
  direction: 'debit' | 'credit'
  bankTransactionId: number | null
}

export interface JournalEntry {
  id: number
  bookingDate: string
  description: string
  postedAt: string | null
  fiscalYearId: number
  fiscalYearClosed: boolean
  lineItems: LineItem[]
}

export type VatPatternType = 'vat_expense' | 'vat_revenue' | 'reverse_charge' | 'none'

export interface VatPattern {
  type: VatPatternType
  mainAccount: LineItem | null
  bankAccount: LineItem | null
  vatAccount?: LineItem
  reverseChargeInput?: LineItem
  reverseChargeOutput?: LineItem
  vatRate?: number  // 7 or 19
  grossAmount: number
  netAmount?: number
  vatAmount?: number
}

export interface UserConfig {
  ui?: {
    theme?: 'light' | 'dark'
    simplified_journal_view?: boolean
  }
  fiscal_years?: Record<string, number>
}
