import type { JournalEntry, LineItem, VatPattern } from '@/types/journal-entries'

/**
 * Main function to detect VAT patterns in a journal entry.
 * Returns a VatPattern object describing the detected pattern.
 */
export function detectVatPattern(entry: JournalEntry): VatPattern {
  // Early exit for non-matching counts
  if (entry.lineItems.length === 3) {
    const expensePattern = detectVatExpense(entry.lineItems)
    if (expensePattern) return expensePattern

    const revenuePattern = detectVatRevenue(entry.lineItems)
    if (revenuePattern) return revenuePattern
  }

  if (entry.lineItems.length === 4) {
    const reverseChargePattern = detectReverseCharge(entry.lineItems)
    if (reverseChargePattern) return reverseChargePattern
  }

  // No pattern detected
  return {
    type: 'none',
    mainAccount: null,
    bankAccount: null,
    grossAmount: 0,
  }
}

/**
 * Detects VAT expense pattern:
 * - Bank account (credit)
 * - Expense account (debit)
 * - Input VAT account (debit): 1576 (19%) or 1571 (7%)
 */
function detectVatExpense(lineItems: LineItem[]): VatPattern | null {
  if (lineItems.length !== 3) return null

  // Find candidates
  const bankCandidate = lineItems.find(
    (li) => li.direction === 'credit' && isBankAccount(li)
  )
  const vatCandidate = lineItems.find((li) => {
    const vatInfo = isVatInputAccount(li.accountCode)
    return li.direction === 'debit' && vatInfo.isVat
  })
  const expenseCandidate = lineItems.find(
    (li) =>
      li.direction === 'debit' &&
      li.id !== vatCandidate?.id &&
      !isBankAccount(li)
  )

  if (!bankCandidate || !vatCandidate || !expenseCandidate) return null

  const vatInfo = isVatInputAccount(vatCandidate.accountCode)
  if (!vatInfo.isVat || !vatInfo.rate) return null

  // Validate amounts
  const grossAmount = bankCandidate.amount
  const netAmount = expenseCandidate.amount
  const vatAmount = vatCandidate.amount

  // Check: Bank amount = Expense amount + VAT amount (±0.01 tolerance)
  if (!amountsBalance(grossAmount, netAmount, vatAmount)) return null

  // Check: VAT rate matches
  if (!vatRateMatches(vatAmount, netAmount, vatInfo.rate)) return null

  return {
    type: 'vat_expense',
    mainAccount: expenseCandidate,
    bankAccount: bankCandidate,
    vatAccount: vatCandidate,
    vatRate: vatInfo.rate,
    grossAmount,
    netAmount,
    vatAmount,
  }
}

/**
 * Detects VAT revenue pattern:
 * - Bank account (debit)
 * - Revenue account (credit)
 * - Output VAT account (credit): 1776 (19%) or 1771 (7%)
 */
function detectVatRevenue(lineItems: LineItem[]): VatPattern | null {
  if (lineItems.length !== 3) return null

  // Find candidates
  const bankCandidate = lineItems.find(
    (li) => li.direction === 'debit' && isBankAccount(li)
  )
  const vatCandidate = lineItems.find((li) => {
    const vatInfo = isVatOutputAccount(li.accountCode)
    return li.direction === 'credit' && vatInfo.isVat
  })
  const revenueCandidate = lineItems.find(
    (li) =>
      li.direction === 'credit' &&
      li.id !== vatCandidate?.id &&
      !isBankAccount(li)
  )

  if (!bankCandidate || !vatCandidate || !revenueCandidate) return null

  const vatInfo = isVatOutputAccount(vatCandidate.accountCode)
  if (!vatInfo.isVat || !vatInfo.rate) return null

  // Validate amounts
  const grossAmount = bankCandidate.amount
  const netAmount = revenueCandidate.amount
  const vatAmount = vatCandidate.amount

  // Check: Bank amount = Revenue amount + VAT amount (±0.01 tolerance)
  if (!amountsBalance(grossAmount, netAmount, vatAmount)) return null

  // Check: VAT rate matches
  if (!vatRateMatches(vatAmount, netAmount, vatInfo.rate)) return null

  return {
    type: 'vat_revenue',
    mainAccount: revenueCandidate,
    bankAccount: bankCandidate,
    vatAccount: vatCandidate,
    vatRate: vatInfo.rate,
    grossAmount,
    netAmount,
    vatAmount,
  }
}

/**
 * Detects reverse charge pattern (§13b UStG):
 * - Bank account
 * - Main account (expense or revenue)
 * - Reverse charge input VAT (1577) - same direction as main account
 * - Reverse charge output VAT (1787) - opposite direction
 * - Input VAT amount = Output VAT amount
 */
function detectReverseCharge(lineItems: LineItem[]): VatPattern | null {
  if (lineItems.length !== 4) return null

  // Find bank account
  const bankCandidate = lineItems.find((li) => isBankAccount(li))
  if (!bankCandidate) return null

  // Find reverse charge VAT accounts
  const inputVatCandidate = lineItems.find((li) =>
    isReverseChargeInput(li.accountCode)
  )
  const outputVatCandidate = lineItems.find((li) =>
    isReverseChargeOutput(li.accountCode)
  )

  if (!inputVatCandidate || !outputVatCandidate) return null

  // VAT amounts must match
  if (Math.abs(inputVatCandidate.amount - outputVatCandidate.amount) > 0.01) {
    return null
  }

  // Find main account (the one that's not bank or VAT)
  const mainCandidate = lineItems.find(
    (li) =>
      li.id !== bankCandidate.id &&
      li.id !== inputVatCandidate.id &&
      li.id !== outputVatCandidate.id
  )

  if (!mainCandidate) return null

  // Validate: Input VAT must have same direction as main account
  if (inputVatCandidate.direction !== mainCandidate.direction) return null

  // Validate: Output VAT must have opposite direction
  if (outputVatCandidate.direction === mainCandidate.direction) return null

  // Validate: VAT amount should be ~19% of main amount
  const vatAmount = inputVatCandidate.amount
  const mainAmount = mainCandidate.amount
  if (!vatRateMatches(vatAmount, mainAmount, 19)) return null

  return {
    type: 'reverse_charge',
    mainAccount: mainCandidate,
    bankAccount: bankCandidate,
    reverseChargeInput: inputVatCandidate,
    reverseChargeOutput: outputVatCandidate,
    vatRate: 19,
    grossAmount: mainAmount,
    netAmount: mainAmount,
    vatAmount,
  }
}

/**
 * Identifies if a line item is a bank account.
 * Bank accounts typically have a bankTransactionId linkage.
 */
function isBankAccount(lineItem: LineItem): boolean {
  // A line item is considered a bank account if it has a bank transaction link
  // OR if it's in the typical bank account code range (1200-1299 in SKR03)
  return (
    lineItem.bankTransactionId !== null ||
    (lineItem.accountCode >= '1200' && lineItem.accountCode <= '1299')
  )
}

/**
 * Checks if an account code is an input VAT account.
 * Returns the VAT rate if it is.
 */
function isVatInputAccount(accountCode: string): { isVat: boolean; rate?: number } {
  if (accountCode === '1576') return { isVat: true, rate: 19 }
  if (accountCode === '1571') return { isVat: true, rate: 7 }
  return { isVat: false }
}

/**
 * Checks if an account code is an output VAT account.
 * Returns the VAT rate if it is.
 */
function isVatOutputAccount(accountCode: string): { isVat: boolean; rate?: number } {
  if (accountCode === '1776') return { isVat: true, rate: 19 }
  if (accountCode === '1771') return { isVat: true, rate: 7 }
  return { isVat: false }
}

/**
 * Checks if an account code is a reverse charge input VAT account (1577).
 */
function isReverseChargeInput(accountCode: string): boolean {
  return accountCode === '1577'
}

/**
 * Checks if an account code is a reverse charge output VAT account (1787).
 */
function isReverseChargeOutput(accountCode: string): boolean {
  return accountCode === '1787'
}

/**
 * Validates that gross = net + vat (with 0.01 tolerance for rounding).
 */
function amountsBalance(gross: number, net: number, vat: number): boolean {
  return Math.abs(gross - (net + vat)) <= 0.01
}

/**
 * Validates that VAT amount matches expected rate.
 * e.g., for 19% VAT: vatAmount / netAmount ≈ 0.19
 */
function vatRateMatches(
  vatAmount: number,
  netAmount: number,
  expectedRate: number
): boolean {
  if (netAmount === 0) return false
  const actualRate = (vatAmount / netAmount) * 100
  // Allow 0.5% tolerance for rounding differences
  return Math.abs(actualRate - expectedRate) <= 0.5
}
