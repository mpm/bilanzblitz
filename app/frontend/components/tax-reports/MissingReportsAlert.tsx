import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'
import { AlertCircle } from 'lucide-react'
import type { MissingPeriod } from '@/types/tax-reports'

interface MissingReportsAlertProps {
  calendarYear: number
  reportType: 'ustva' | 'kst'
  periodType: 'monthly' | 'quarterly' | 'annual'
  missingPeriods: MissingPeriod[]
}

export function MissingReportsAlert({
  calendarYear,
  reportType,
  periodType,
  missingPeriods
}: MissingReportsAlertProps) {
  if (missingPeriods.length === 0) {
    return null
  }

  const reportTypeLabel = reportType === 'ustva' ? 'UStVA' : 'KSt'
  const periodTypeLabel = {
    monthly: 'monthly',
    quarterly: 'quarterly',
    annual: 'annual'
  }[periodType]

  return (
    <Alert variant="default" className="border-yellow-200 bg-yellow-50">
      <AlertCircle className="h-4 w-4 text-yellow-600" />
      <AlertTitle className="text-yellow-800">Missing Reports</AlertTitle>
      <AlertDescription className="text-yellow-700">
        <p className="mb-2">
          The following {periodTypeLabel} {reportTypeLabel} reports are missing for {calendarYear}:
        </p>
        <ul className="list-disc list-inside space-y-1">
          {missingPeriods.map((period, index) => (
            <li key={index}>{period.label}</li>
          ))}
        </ul>
      </AlertDescription>
    </Alert>
  )
}
