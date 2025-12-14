/**
 * Shared formatting utilities for the BilanzBlitz application.
 * These functions handle German locale formatting for dates, currencies, and amounts.
 */

/**
 * Format a date string to German locale format (DD.MM.YYYY)
 * @param dateString - ISO date string or null
 * @param options - Optional Intl.DateTimeFormatOptions for custom formatting
 * @returns Formatted date string or '-' if null
 */
export function formatDate(
  dateString: string | null,
  options?: Intl.DateTimeFormatOptions
): string {
  if (!dateString) return '-'

  const defaultOptions: Intl.DateTimeFormatOptions = {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }

  return new Date(dateString).toLocaleDateString('de-DE', options || defaultOptions)
}

/**
 * Format an amount with currency symbol in German locale format
 * @param amount - The numeric amount
 * @param currency - ISO currency code (e.g., 'EUR')
 * @returns Formatted currency string (e.g., '1.234,56 €')
 */
export function formatAmount(amount: number, currency: string): string {
  return new Intl.NumberFormat('de-DE', {
    style: 'currency',
    currency,
  }).format(amount)
}

/**
 * Format a currency amount, handling null values
 * @param amount - The numeric amount or null
 * @param currency - ISO currency code (default: 'EUR')
 * @returns Formatted currency string or '-' if null
 */
export function formatCurrency(amount: number | null, currency: string = 'EUR'): string {
  if (amount === null) return '-'
  return formatAmount(amount, currency)
}
