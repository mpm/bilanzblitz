import { Head, router } from '@inertiajs/react'
import { AppLayout } from '@/components/AppLayout'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { AlertCircle, Save, ArrowLeft, Edit } from 'lucide-react'
import { TaxReportSection } from '@/components/tax-reports/TaxReportSection'
import { ReportTypeBadge } from '@/components/tax-reports/ReportTypeBadge'
import { formatCurrency, formatDate } from '@/utils/formatting'
import type { Company, TaxReportSummary, TaxReportData, KstData, FiscalYear } from '@/types/tax-reports'
import { useState, useMemo } from 'react'

interface TaxReportsShowProps {
  company: Company
  taxReport?: TaxReportSummary
  reportData: TaxReportData
  isPreview: boolean
  fiscalYears: FiscalYear[]
  errors?: string[]
}

export default function Show({
  company,
  taxReport,
  reportData,
  isPreview,
  fiscalYears,
  errors
}: TaxReportsShowProps) {
  const [adjustments, setAdjustments] = useState<Record<string, number>>({})
  const [isSaving, setIsSaving] = useState(false)
  const [isUpdating, setIsUpdating] = useState(false)

  const isUstva = reportData.reportType === 'ustva'
  const isKst = reportData.reportType === 'kst'

  // Handle KSt adjustment changes
  const handleAdjustmentChange = (key: string, value: number) => {
    setAdjustments(prev => ({ ...prev, [key]: value }))
  }

  // Save report to database
  const handleSave = () => {
    if (!isPreview) return

    setIsSaving(true)

    const payload: any = {
      tax_report: {
        report_type: reportData.reportType,
        period_type: isUstva ? reportData.periodType : 'annual',
        start_date: isUstva ? reportData.startDate : (reportData as KstData).fiscalYearId,
        end_date: isUstva ? reportData.endDate : (reportData as KstData).year,
        generated_data: reportData
      }
    }

    if (isKst) {
      const kstData = reportData as KstData
      payload.tax_report.fiscal_year_id = kstData.fiscalYearId
      const fiscalYear = fiscalYears.find(fy => fy.id === kstData.fiscalYearId)
      if (fiscalYear) {
        payload.tax_report.start_date = fiscalYear.startDate
        payload.tax_report.end_date = fiscalYear.endDate
      }
    }

    router.post('/tax_reports', payload)
  }

  // Update KSt adjustments
  const handleUpdateAdjustments = () => {
    if (!taxReport || !isKst) return

    setIsUpdating(true)

    router.patch(`/tax_reports/${taxReport.id}`, {
      tax_report: {
        adjustments
      }
    })
  }

  // Check if adjustments have been modified
  const hasModifiedAdjustments = useMemo(() => {
    return Object.keys(adjustments).length > 0
  }, [adjustments])

  return (
    <AppLayout company={company} currentPage="tax-reports">
      <Head title={isPreview ? 'Preview Tax Report' : 'Tax Report'} />

      <div className="container mx-auto py-6 space-y-6">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-4">
            <Button
              variant="ghost"
              size="sm"
              onClick={() => router.visit('/tax_reports')}
            >
              <ArrowLeft className="w-4 h-4 mr-2" />
              Back to Reports
            </Button>
            <div>
              <div className="flex items-center gap-3">
                <h1 className="text-3xl font-bold">
                  {isPreview ? 'Preview Tax Report' : 'Tax Report'}
                </h1>
                {!isPreview && taxReport && (
                  <Badge variant={taxReport.status === 'draft' ? 'secondary' : 'default'}>
                    {taxReport.status}
                  </Badge>
                )}
              </div>
              <p className="text-muted-foreground">
                {isUstva && `${reportData.periodType} report for ${reportData.startDate} - ${reportData.endDate}`}
                {isKst && `Annual report for fiscal year ${(reportData as KstData).year}`}
              </p>
            </div>
          </div>
          <div className="flex gap-2">
            {isPreview && (
              <Button onClick={handleSave} disabled={isSaving}>
                <Save className="w-4 h-4 mr-2" />
                {isSaving ? 'Saving...' : 'Save Report'}
              </Button>
            )}
            {!isPreview && isKst && taxReport?.editable && hasModifiedAdjustments && (
              <Button onClick={handleUpdateAdjustments} disabled={isUpdating}>
                <Edit className="w-4 h-4 mr-2" />
                {isUpdating ? 'Updating...' : 'Update Adjustments'}
              </Button>
            )}
          </div>
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

        {/* Report Header Card */}
        <Card>
          <CardHeader>
            <div className="flex items-center justify-between">
              <div>
                <CardTitle className="flex items-center gap-3">
                  <ReportTypeBadge reportType={reportData.reportType} />
                  <span>
                    {isUstva && 'Umsatzsteuervoranmeldung (UStVA)'}
                    {isKst && 'Körperschaftsteuer (KSt)'}
                  </span>
                </CardTitle>
                <CardDescription>
                  {isUstva && `VAT Advance Return - ${reportData.periodType}`}
                  {isKst && 'Corporate Income Tax'}
                </CardDescription>
              </div>
            </div>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-2 gap-4 text-sm">
              <div>
                <span className="text-muted-foreground">Period:</span>
                <div className="font-medium">
                  {isUstva && `${formatDate(reportData.startDate)} - ${formatDate(reportData.endDate)}`}
                  {isKst && (reportData as KstData).year}
                </div>
              </div>
              <div>
                <span className="text-muted-foreground">Calculated:</span>
                <div className="font-medium">{formatDate(reportData.metadata.calculationDate)}</div>
              </div>
              {isUstva && (
                <div>
                  <span className="text-muted-foreground">Journal Entries:</span>
                  <div className="font-medium">{reportData.metadata.journalEntriesCount}</div>
                </div>
              )}
              {isKst && (
                <div>
                  <span className="text-muted-foreground">Balance Sheet Available:</span>
                  <div className="font-medium">
                    {(reportData as KstData).baseData.balanceSheetAvailable ? 'Yes' : 'No'}
                  </div>
                </div>
              )}
            </div>
          </CardContent>
        </Card>

        {/* UStVA Report */}
        {isUstva && (
          <>
            <TaxReportSection
              title="Umsatzsteuer (Output VAT)"
              fields={reportData.sections.outputVat.fields}
              subtotal={reportData.sections.outputVat.subtotal}
              showFieldNumbers={true}
            />

            <TaxReportSection
              title="Abziehbare Vorsteuer (Input VAT)"
              fields={reportData.sections.inputVat.fields}
              subtotal={reportData.sections.inputVat.subtotal}
              showFieldNumbers={true}
            />

            <TaxReportSection
              title="Reverse Charge (§ 13b UStG)"
              fields={reportData.sections.reverseCharge.fields}
              subtotal={reportData.sections.reverseCharge.subtotal}
              showFieldNumbers={true}
            />

            {/* Net VAT Liability */}
            <Card className="border-2 border-primary">
              <CardHeader>
                <CardTitle>Net VAT Liability</CardTitle>
                <CardDescription>
                  {reportData.netVatLiability >= 0
                    ? 'Amount to be paid to tax authority'
                    : 'VAT refund from tax authority'}
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold">
                  {formatCurrency(reportData.netVatLiability)}
                </div>
              </CardContent>
            </Card>
          </>
        )}

        {/* KSt Report */}
        {isKst && (
          <>
            {/* Base Data */}
            <Card>
              <CardHeader>
                <CardTitle>Ausgangswerte (Base Data)</CardTitle>
                <CardDescription>Net income from GuV (Profit & Loss Statement)</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-2">
                  <div className="flex justify-between items-center py-2">
                    <span className="font-medium">{(reportData as KstData).baseData.netIncomeLabel}</span>
                    <span className="text-xl font-bold">
                      {formatCurrency((reportData as KstData).baseData.netIncome)}
                    </span>
                  </div>
                  {!(reportData as KstData).baseData.guvAvailable && (
                    <Alert>
                      <AlertCircle className="h-4 w-4" />
                      <AlertDescription>
                        GuV data was generated on-the-fly for this report. Consider closing the fiscal year to store final values.
                      </AlertDescription>
                    </Alert>
                  )}
                </div>
              </CardContent>
            </Card>

            {/* Adjustments */}
            <Card>
              <CardHeader>
                <CardTitle>Außerbilanzielle Korrekturen (Tax Adjustments)</CardTitle>
                <CardDescription>
                  {taxReport?.editable
                    ? 'Edit adjustments below and click "Update Adjustments" to recalculate'
                    : 'Adjustments applied to calculate taxable income'}
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-3">
                  {Object.entries((reportData as KstData).adjustments).map(([key, adjustment]) => (
                    <TaxReportSection
                      key={key}
                      title=""
                      fields={[{
                        key,
                        name: adjustment.name,
                        description: adjustment.description,
                        value: adjustment.value,
                        editable: adjustment.editable
                      }]}
                      showFieldNumbers={false}
                      editable={taxReport?.editable ?? isPreview}
                      onFieldChange={handleAdjustmentChange}
                    />
                  ))}
                </div>
              </CardContent>
            </Card>

            {/* Calculated Values */}
            <Card className="border-2 border-primary">
              <CardHeader>
                <CardTitle>Berechnete Werte (Calculated Values)</CardTitle>
                <CardDescription>Final taxable income and corporate tax amount</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  <div className="flex justify-between items-center py-2 border-b">
                    <span className="font-medium">Zu versteuerndes Einkommen (Taxable Income)</span>
                    <span className="text-xl font-bold">
                      {formatCurrency((reportData as KstData).calculated.taxableIncome)}
                    </span>
                  </div>
                  <div className="flex justify-between items-center py-2 border-b">
                    <span className="font-medium">Körperschaftsteuersatz (Tax Rate)</span>
                    <span className="text-xl font-bold">
                      {((reportData as KstData).calculated.kstRate * 100).toFixed(0)}%
                    </span>
                  </div>
                  <div className="border-t-2 my-2"></div>
                  <div className="flex justify-between items-center py-2">
                    <span className="text-lg font-semibold">Körperschaftsteuer (Corporate Tax)</span>
                    <span className="text-3xl font-bold text-primary">
                      {formatCurrency((reportData as KstData).calculated.kstAmount)}
                    </span>
                  </div>
                </div>
              </CardContent>
            </Card>
          </>
        )}
      </div>
    </AppLayout>
  )
}
