// TypeScript type definitions for accounting data structures

// Account balance interface (shared by Balance Sheet and GuV)
export interface AccountBalance {
  accountCode: string
  accountName: string
  balance: number
}

// GuV Section
export interface GuVSection {
  key: string
  label: string
  accounts: AccountBalance[]
  subtotal: number
  displayType: 'positive' | 'negative' | 'neutral'
}

// GuV Data Structure
export interface GuVData {
  sections: GuVSection[]
  netIncome: number
  netIncomeLabel: string
}

// Fiscal Year
export interface FiscalYear {
  id: number
  year: number
  startDate: string
  endDate: string
  closed: boolean
  openingBalancePostedAt: string | null
  closingBalancePostedAt: string | null
  workflowState: 'open' | 'open_with_opening' | 'closing_posted' | 'closed'
}

// Balance Sheet Data Structure
export interface BalanceSheetData {
  fiscalYear: FiscalYear
  aktiva: {
    anlagevermoegen: AccountBalance[]
    umlaufvermoegen: AccountBalance[]
    total: number
  }
  passiva: {
    eigenkapital: AccountBalance[]
    fremdkapital: AccountBalance[]
    total: number
  }
  balanced: boolean
  guv?: GuVData // Optional for backward compatibility
  stored?: boolean
  postedAt?: string
}
