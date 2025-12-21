// TypeScript type definitions for accounting data structures

// Account balance interface (shared by Balance Sheet and GuV)
export interface AccountBalance {
  id?: number  // Optional, needed for ledger popover integration
  code: string
  name: string
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

// Bank Transaction
export interface BankTransaction {
  id: number
  bookingDate: string
  valueDate: string | null
  amount: number
  currency: string
  remittanceInformation: string | null
  counterpartyName: string | null
  counterpartyIban: string | null
  status: 'pending' | 'booked' | 'reconciled'
  config: Record<string, unknown>
  journalEntryId: number | null
  journalEntryPosted: boolean | null
}

// Balance Sheet Data Structure
export interface BalanceSheetData {
  fiscalYear: FiscalYear
  aktiva: {
    sections: Record<string, BalanceSheetSectionNested>
    total: number
  }
  passiva: {
    sections: Record<string, BalanceSheetSectionNested>
    total: number
  }
  balanced: boolean
  guv?: GuVData
  stored?: boolean
  postedAt?: string
}

// Nested Balance Sheet Section (optional, for future use)
export interface BalanceSheetSectionNested {
  sectionKey: string
  sectionName: string
  level: number
  accounts: AccountBalance[]
  ownTotal: number
  total: number
  accountCount: number
  totalAccountCount: number
  children?: BalanceSheetSectionNested[]
}

// Account with statistics (for account overview)
export interface AccountWithStats {
  id: number
  code: string
  name: string
  accountType: string
  balance: number
  lineItemCount: number
}

// Line item detail in ledger view
export interface LineItemDetail {
  id: number
  amount: number
  direction: 'debit' | 'credit'
  description: string | null
  accountCode: string
  accountName: string
}

// Line items grouped by journal entry
export interface LineItemGroup {
  journalEntryId: number
  bookingDate: string
  description: string
  postedAt: string | null
  fiscalYearClosed: boolean
  lineItems: LineItemDetail[]
}

// Account ledger data structure
export interface AccountLedgerData {
  account: {
    id: number
    code: string
    name: string
    accountType: string
  }
  fiscalYear: FiscalYear | null
  balance: number
  lineItemGroups: LineItemGroup[]
}
