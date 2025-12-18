import { Head, router } from '@inertiajs/react'
import { AppLayout } from '@/components/AppLayout'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Label } from '@/components/ui/label'
import { RadioGroupItem } from '@/components/ui/radio-group'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { AlertCircle, FileText } from 'lucide-react'
import type { Company, FiscalYear, ReportTypeConfig } from '@/types/tax-reports'
import { useState, useMemo } from 'react'

interface TaxReportsNewProps {
  company: Company
  fiscalYears: FiscalYear[]
  reportTypes: Record<string, ReportTypeConfig>
  errors?: string[]
}

export default function New({ company, fiscalYears, reportTypes, errors }: TaxReportsNewProps) {
  const [reportType, setReportType] = useState<string>('')
  const [periodType, setPeriodType] = useState<string>('')
  const [selectedYear, setSelectedYear] = useState<string>('')
  const [selectedMonth, setSelectedMonth] = useState<string>('')
  const [selectedQuarter, setSelectedQuarter] = useState<string>('')
  const [selectedFiscalYearId, setSelectedFiscalYearId] = useState<string>('')
  const [isGenerating, setIsGenerating] = useState(false)

  const currentYear = new Date().getFullYear()
  // const availableYears = [currentYear - 1, currentYear, currentYear + 1]
  const availableYears = fiscalYears.map(fy => fy.year)

  // Get available period types for selected report type
  const availablePeriodTypes = useMemo(() => {
    if (!reportType || !reportTypes[reportType]) return []
    return reportTypes[reportType].periodTypes
  }, [reportType, reportTypes])

  // Reset period type when report type changes
  const handleReportTypeChange = (value: string) => {
    setReportType(value)
    setPeriodType('')
    setSelectedYear('')
    setSelectedMonth('')
    setSelectedQuarter('')
    setSelectedFiscalYearId('')
  }

  // Calculate date range based on selections
  const getDateRange = (): { startDate: string; endDate: string } | null => {
    if (!selectedYear) return null

    const year = parseInt(selectedYear)

    switch (periodType) {
      case 'monthly':
        if (!selectedMonth) return null
        const month = parseInt(selectedMonth) - 1 // 0-indexed
        const startDate = new Date(year, month, 1)
        const endDate = new Date(year, month + 1, 0)
        return {
          startDate: formatDate(startDate),
          endDate: formatDate(endDate)
        }

      case 'quarterly':
        if (!selectedQuarter) return null
        const quarter = parseInt(selectedQuarter)
        const startMonth = (quarter - 1) * 3
        const qStartDate = new Date(year, startMonth, 1)
        const qEndDate = new Date(year, startMonth + 3, 0)
        return {
          startDate: formatDate(qStartDate),
          endDate: formatDate(qEndDate)
        }

      case 'annual':
        return {
          startDate: `${year}-01-01`,
          endDate: `${year}-12-31`
        }

      default:
        return null
    }
  }

  const canGenerate = useMemo(() => {
    if (!reportType || !periodType) return false

    if (reportType === 'kst') {
      return !!selectedFiscalYearId
    }

    // For UStVA and other date-based reports
    const dateRange = getDateRange()
    return !!dateRange
  }, [reportType, periodType, selectedYear, selectedMonth, selectedQuarter, selectedFiscalYearId])

  const handleGenerate = () => {
    if (!canGenerate) return

    setIsGenerating(true)

    const payload: any = {
      tax_report: {
        report_type: reportType,
        period_type: periodType
      }
    }

    if (reportType === 'kst') {
      payload.tax_report.fiscal_year_id = parseInt(selectedFiscalYearId)
      // Use fiscal year dates
      const fiscalYear = fiscalYears.find(fy => fy.id === parseInt(selectedFiscalYearId))
      if (fiscalYear) {
        payload.tax_report.start_date = fiscalYear.startDate
        payload.tax_report.end_date = fiscalYear.endDate
      }
    } else {
      const dateRange = getDateRange()
      if (dateRange) {
        payload.tax_report.start_date = dateRange.startDate
        payload.tax_report.end_date = dateRange.endDate
      }
    }

    router.post('/tax_reports/generate', payload)
  }

  const monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ]

  return (
    <AppLayout company={company} currentPage="tax-reports">
      <Head title="Generate Tax Report" />

      <div className="container mx-auto py-6 max-w-3xl space-y-6">
        {/* Header */}
        <div>
          <h1 className="text-3xl font-bold">Generate Tax Report</h1>
          <p className="text-muted-foreground">
            Select report type and period to generate a tax report
          </p>
        </div>

        {/* Errors */}
        {errors && errors.length > 0 && (
          <Alert variant="destructive">
            <AlertCircle className="h-4 w-4" />
            <AlertDescription>
              <ul className="list-disc list-inside">
                {errors.map((error, index) => (
                  <li key={index}>{error}</li>
                ))}
              </ul>
            </AlertDescription>
          </Alert>
        )}

        {/* Step 1: Report Type Selection */}
        <Card>
          <CardHeader>
            <CardTitle>Step 1: Select Report Type</CardTitle>
            <CardDescription>Choose the type of tax report to generate</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              {Object.entries(reportTypes).map(([key, config]) => (
                <div key={key} className="flex items-start space-x-3">
                  <RadioGroupItem
                    value={key}
                    id={`report-type-${key}`}
                    name="report-type"
                    checked={reportType === key}
                    onChange={() => handleReportTypeChange(key)}
                  />
                  <Label htmlFor={`report-type-${key}`} className="font-normal cursor-pointer flex-1">
                    <div className="font-semibold">{config.name}</div>
                    <div className="text-sm text-muted-foreground">{config.description}</div>
                  </Label>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>

        {/* Step 2: Period Type Selection */}
        {reportType && (
          <Card>
            <CardHeader>
              <CardTitle>Step 2: Select Period Type</CardTitle>
              <CardDescription>Choose the reporting period frequency</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-3">
                {availablePeriodTypes.map((type) => (
                  <div key={type} className="flex items-center space-x-3">
                    <RadioGroupItem
                      value={type}
                      id={`period-type-${type}`}
                      name="period-type"
                      checked={periodType === type}
                      onChange={() => setPeriodType(type)}
                    />
                    <Label htmlFor={`period-type-${type}`} className="font-normal cursor-pointer capitalize">
                      {type}
                    </Label>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        )}

        {/* Step 3: Period Selection */}
        {periodType && (
          <Card>
            <CardHeader>
              <CardTitle>Step 3: Select Period</CardTitle>
              <CardDescription>
                {reportType === 'kst'
                  ? 'Choose the fiscal year for this report'
                  : 'Choose the specific time period for this report'}
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              {reportType === 'kst' ? (
                // KSt uses fiscal years
                <div>
                  <Label htmlFor="fiscal-year">Fiscal Year</Label>
                  <Select value={selectedFiscalYearId} onValueChange={setSelectedFiscalYearId}>
                    <SelectTrigger id="fiscal-year">
                      <SelectValue placeholder="Select fiscal year" />
                    </SelectTrigger>
                    <SelectContent>
                      {fiscalYears.map((fy) => (
                        <SelectItem key={fy.id} value={fy.id.toString()}>
                          {fy.year} ({fy.startDate} - {fy.endDate})
                          {fy.closed && ' [Closed]'}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              ) : (
                // UStVA and others use calendar periods
                <>
                  <div>
                    <Label htmlFor="year">Year</Label>
                    <Select value={selectedYear} onValueChange={setSelectedYear}>
                      <SelectTrigger id="year">
                        <SelectValue placeholder="Select year" />
                      </SelectTrigger>
                      <SelectContent>
                        {availableYears.map((year) => (
                          <SelectItem key={year} value={year.toString()}>
                            {year}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>

                  {periodType === 'monthly' && selectedYear && (
                    <div>
                      <Label htmlFor="month">Month</Label>
                      <Select value={selectedMonth} onValueChange={setSelectedMonth}>
                        <SelectTrigger id="month">
                          <SelectValue placeholder="Select month" />
                        </SelectTrigger>
                        <SelectContent>
                          {monthNames.map((name, index) => (
                            <SelectItem key={index + 1} value={(index + 1).toString()}>
                              {name}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </div>
                  )}

                  {periodType === 'quarterly' && selectedYear && (
                    <div>
                      <Label htmlFor="quarter">Quarter</Label>
                      <Select value={selectedQuarter} onValueChange={setSelectedQuarter}>
                        <SelectTrigger id="quarter">
                          <SelectValue placeholder="Select quarter" />
                        </SelectTrigger>
                        <SelectContent>
                          {[1, 2, 3, 4].map((q) => (
                            <SelectItem key={q} value={q.toString()}>
                              Q{q}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </div>
                  )}
                </>
              )}
            </CardContent>
          </Card>
        )}

        {/* Generate Button */}
        <div className="flex justify-end gap-3">
          <Button
            variant="outline"
            onClick={() => router.visit('/tax_reports')}
          >
            Cancel
          </Button>
          <Button
            onClick={handleGenerate}
            disabled={!canGenerate || isGenerating}
          >
            <FileText className="w-4 h-4 mr-2" />
            {isGenerating ? 'Generating...' : 'Generate Report'}
          </Button>
        </div>
      </div>
    </AppLayout>
  )
}

function formatDate(date: Date): string {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}
