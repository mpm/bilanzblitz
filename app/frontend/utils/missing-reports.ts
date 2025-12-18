import type { TaxReportSummary, MissingPeriod } from '@/types/tax-reports'

/**
 * Calculate which periods are missing for a given year/report type/period type
 */
export function calculateMissingPeriods(
  calendarYear: number,
  reportType: 'ustva' | 'kst',
  periodType: 'monthly' | 'quarterly' | 'annual',
  existingReports: TaxReportSummary[]
): MissingPeriod[] {
  // Generate all expected periods for the year
  const expectedPeriods = generateExpectedPeriods(calendarYear, periodType)

  // Filter existing reports to only those matching the criteria
  const relevantReports = existingReports.filter(
    (r) => r.reportType === reportType && r.periodType === periodType
  )

  // Create a Set of existing period keys for fast lookup
  const existingPeriodKeys = new Set(
    relevantReports.map((r) => `${r.startDate}_${r.endDate}`)
  )

  // Return periods that don't exist
  return expectedPeriods.filter(
    (p) => !existingPeriodKeys.has(`${p.startDate}_${p.endDate}`)
  )
}

/**
 * Generate all expected periods for a given year and period type
 */
export function generateExpectedPeriods(
  year: number,
  periodType: 'monthly' | 'quarterly' | 'annual'
): MissingPeriod[] {
  switch (periodType) {
    case 'monthly':
      return generateMonthlyPeriods(year)
    case 'quarterly':
      return generateQuarterlyPeriods(year)
    case 'annual':
      return generateAnnualPeriods(year)
    default:
      return []
  }
}

/**
 * Generate 12 monthly periods (Jan-Dec) for a year
 */
function generateMonthlyPeriods(year: number): MissingPeriod[] {
  const periods: MissingPeriod[] = []
  const monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ]

  for (let month = 0; month < 12; month++) {
    const startDate = new Date(year, month, 1)
    const endDate = new Date(year, month + 1, 0) // Last day of month

    periods.push({
      label: `${monthNames[month]} ${year}`,
      startDate: formatDate(startDate),
      endDate: formatDate(endDate)
    })
  }

  return periods
}

/**
 * Generate 4 quarterly periods for a year
 */
function generateQuarterlyPeriods(year: number): MissingPeriod[] {
  const periods: MissingPeriod[] = []

  for (let quarter = 1; quarter <= 4; quarter++) {
    const startMonth = (quarter - 1) * 3
    const startDate = new Date(year, startMonth, 1)
    const endDate = new Date(year, startMonth + 3, 0) // Last day of third month

    periods.push({
      label: `Q${quarter} ${year}`,
      startDate: formatDate(startDate),
      endDate: formatDate(endDate)
    })
  }

  return periods
}

/**
 * Generate single annual period for a year
 */
function generateAnnualPeriods(year: number): MissingPeriod[] {
  return [{
    label: year.toString(),
    startDate: `${year}-01-01`,
    endDate: `${year}-12-31`
  }]
}

/**
 * Format a Date object to YYYY-MM-DD string
 */
function formatDate(date: Date): string {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}
