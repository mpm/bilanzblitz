import { Head, router } from '@inertiajs/react'
import { AppLayout } from '@/components/AppLayout'
import { Card, CardContent } from '@/components/ui/card'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Badge } from '@/components/ui/badge'
import { FiscalYearStatusBadge } from '@/components/FiscalYearStatusBadge'
import { AlertCircle, FileText } from 'lucide-react'
import { formatCurrency } from '@/utils/formatting'
import { BalanceSheetSection } from '@/components/reports/BalanceSheetSection'
import { GuVSection } from '@/components/reports/GuVSection'
import { BalanceSheetData, FiscalYear } from '@/types/accounting'

interface BalanceSheetProps {
  company: { id: number; name: string }
  fiscalYears: FiscalYear[]
  selectedFiscalYearId: number | null
  balanceSheet: BalanceSheetData | null
  errors: string[]
}

const SHOW_PREVIOUS_YEAR = false // Feature flag for previous year column

export default function BalanceSheet({
  company,
  fiscalYears,
  selectedFiscalYearId,
  balanceSheet,
  errors,
}: BalanceSheetProps) {
  const handleFiscalYearChange = (value: string) => {
    router.visit(`/reports/balance_sheet?fiscal_year_id=${value}`)
  }

  const selectedFiscalYear = fiscalYears.find((fy) => fy.id === selectedFiscalYearId)

  return (
    <AppLayout company={company} currentPage="reports">
      <Head title={`Balance Sheet - ${company.name}`} />

      <div className="space-y-6">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold tracking-tight">Balance Sheet</h1>
            <p className="text-muted-foreground mt-1">
              Bilanz nach SKR03 (Assets and Liabilities)
            </p>
          </div>
        </div>

        {/* Fiscal Year Selector */}
        <div className="flex items-center gap-4">
          <label className="text-sm font-medium">Fiscal Year:</label>
          {fiscalYears.length > 0 ? (
            <Select
              value={selectedFiscalYearId?.toString()}
              onValueChange={handleFiscalYearChange}
            >
              <SelectTrigger className="w-[200px]">
                <SelectValue placeholder="Select fiscal year" />
              </SelectTrigger>
              <SelectContent>
                {fiscalYears.map((fy) => (
                  <SelectItem key={fy.id} value={fy.id.toString()}>
                    {fy.year} {fy.closed && '(Closed)'}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          ) : (
            <span className="text-sm text-muted-foreground">
              No fiscal years found
            </span>
          )}

          {selectedFiscalYear && (
            <div className="flex items-center gap-2">
              <FiscalYearStatusBadge
                workflowState={selectedFiscalYear.workflowState}
              />
              {!selectedFiscalYear.openingBalancePostedAt && (
                <Badge variant="outline" className="text-yellow-600 border-yellow-600">
                  <AlertCircle className="mr-1 h-3 w-3" />
                  No opening balance
                </Badge>
              )}
              {selectedFiscalYear.closed && (
                <Badge variant="secondary">
                  Stored balance sheet
                </Badge>
              )}
            </div>
          )}
        </div>

        {/* Errors */}
        {errors.length > 0 && (
          <Alert variant="destructive">
            <AlertCircle className="h-4 w-4" />
            <AlertDescription>
              {errors.map((error, index) => (
                <div key={index}>{error}</div>
              ))}
            </AlertDescription>
          </Alert>
        )}

        {/* No Fiscal Years */}
        {fiscalYears.length === 0 && (
          <Card>
            <CardContent className="flex flex-col items-center justify-center py-12">
              <div className="rounded-full bg-primary/10 p-3 mb-4">
                <FileText className="h-6 w-6 text-primary" />
              </div>
              <h3 className="font-semibold mb-1">No fiscal years found</h3>
              <p className="text-sm text-muted-foreground text-center max-w-sm">
                Please create a fiscal year first to generate balance sheet reports.
              </p>
            </CardContent>
          </Card>
        )}

        {/* Balance Sheet */}
        {balanceSheet && (
          <>
            {/* Unbalanced Warning */}
            {!balanceSheet.balanced && (
              <Alert variant="destructive">
                <AlertCircle className="h-4 w-4" />
                <AlertDescription>
                  Balance sheet does not balance! This indicates a data integrity
                  issue. Please review journal entries.
                  <div className="mt-2 text-xs">
                    Aktiva: {formatCurrency(balanceSheet.aktiva.total)} |
                    Passiva: {formatCurrency(balanceSheet.passiva.total)}
                  </div>
                </AlertDescription>
              </Alert>
            )}

            {/* No Posted Entries */}
            {balanceSheet.aktiva.total === 0 && balanceSheet.passiva.total === 0 && (
              <Alert>
                <AlertCircle className="h-4 w-4" />
                <AlertDescription>
                  No posted journal entries found for this fiscal year.
                </AlertDescription>
              </Alert>
            )}

            {/* Two-Column Layout with Aligned Tables */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 lg:items-stretch">
              {/* AKTIVA (Assets) */}
              <BalanceSheetSection
                title="Aktiva (Assets)"
                sections={balanceSheet.aktiva.sections}
                total={balanceSheet.aktiva.total}
                fiscalYearId={selectedFiscalYearId}
                showPreviousYear={SHOW_PREVIOUS_YEAR}
              />

              {/* PASSIVA (Liabilities & Equity) */}
              <BalanceSheetSection
                title="Passiva (Liabilities & Equity)"
                sections={balanceSheet.passiva.sections}
                total={balanceSheet.passiva.total}
                fiscalYearId={selectedFiscalYearId}
                showPreviousYear={SHOW_PREVIOUS_YEAR}
              />
            </div>

            {/* GuV Section - Display below balance sheet if available */}
            {balanceSheet.guv && (
              <GuVSection
                guv={balanceSheet.guv}
                fiscalYearId={selectedFiscalYearId}
                showPreviousYear={SHOW_PREVIOUS_YEAR}
              />
            )}

            {/* Missing GuV Notice for Backward Compatibility */}
            {!balanceSheet.guv && (
              <div className="mt-8 text-sm text-muted-foreground text-center">
                GuV (Profit & Loss Statement) not available for this fiscal year.
              </div>
            )}
          </>
        )}
      </div>
    </AppLayout>
  )
}
