import React from 'react'
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
import { AlertCircle, FileText } from 'lucide-react'

interface FiscalYear {
  id: number
  year: number
  startDate: string
  endDate: string
  closed: boolean
}

interface AccountBalance {
  accountCode: string
  accountName: string
  balance: number
}

interface BalanceSheetData {
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
}

interface BalanceSheetProps {
  company: { id: number; name: string }
  fiscalYears: FiscalYear[]
  selectedFiscalYearId: number | null
  balanceSheet: BalanceSheetData | null
  errors: string[]
}

const formatCurrency = (amount: number): string => {
  return new Intl.NumberFormat('de-DE', {
    style: 'currency',
    currency: 'EUR',
  }).format(amount)
}

const SHOW_PREVIOUS_YEAR = false // Feature flag for previous year column

interface BalanceSheetTableProps {
  title: string
  sections: Array<{
    label: string
    accounts: AccountBalance[]
  }>
  total: number
}

const BalanceSheetTable = ({ title, sections, total }: BalanceSheetTableProps) => {
  const hasAccounts = sections.some((section) => section.accounts.length > 0)

  return (
    <div className="flex flex-col h-full">
      <h2 className="text-2xl font-semibold mb-4">{title}</h2>
      <table className="w-full h-full" style={{ borderCollapse: 'collapse' }}>
        <thead>
          <tr className="border-b-2 border-border">
            <th className="text-left py-2 font-semibold text-sm">Position</th>
            <th className="text-right py-2 font-semibold text-sm w-32">
              Current Year
            </th>
            {SHOW_PREVIOUS_YEAR && (
              <th className="text-right py-2 font-semibold text-sm w-32">
                Previous Year
              </th>
            )}
          </tr>
        </thead>
        <tbody>
          {!hasAccounts ? (
            <tr>
              <td
                colSpan={SHOW_PREVIOUS_YEAR ? 3 : 2}
                className="text-center py-6 text-muted-foreground text-sm"
              >
                No accounts with balances
              </td>
            </tr>
          ) : (
            <>
              {sections.map((section, sectionIndex) => (
                <React.Fragment key={sectionIndex}>
                  {/* Section Header */}
                  <tr className="border-t border-border">
                    <td
                      colSpan={SHOW_PREVIOUS_YEAR ? 3 : 2}
                      className="py-3 pt-4 font-semibold text-base"
                    >
                      {section.label}
                    </td>
                  </tr>
                  {/* Account Rows */}
                  {section.accounts.length === 0 ? (
                    <tr>
                      <td
                        colSpan={SHOW_PREVIOUS_YEAR ? 3 : 2}
                        className="pl-6 py-2 text-sm text-muted-foreground italic"
                      >
                        No accounts
                      </td>
                    </tr>
                  ) : (
                    section.accounts.map((account) => (
                      <tr
                        key={account.accountCode}
                        className="hover:bg-accent/50 transition-colors"
                      >
                        <td className="py-2 pl-6">
                          <div className="flex items-center gap-2">
                            <span className="font-mono text-sm text-muted-foreground">
                              {account.accountCode}
                            </span>
                            <span className="text-sm">{account.accountName}</span>
                          </div>
                        </td>
                        <td className="py-2 text-right font-mono text-sm">
                          {formatCurrency(account.balance)}
                        </td>
                        {SHOW_PREVIOUS_YEAR && (
                          <td className="py-2 text-right font-mono text-sm text-muted-foreground">
                            {formatCurrency(0)}
                          </td>
                        )}
                      </tr>
                    ))
                  )}
                </React.Fragment>
              ))}
              {/* Spacer row to push footer to bottom */}
              <tr style={{ height: '100%' }}>
                <td colSpan={SHOW_PREVIOUS_YEAR ? 3 : 2}></td>
              </tr>
            </>
          )}
        </tbody>
        <tfoot>
          <tr className="border-t-2 border-border font-bold">
            <td className="py-3 text-lg">Total</td>
            <td className="py-3 text-right font-mono text-lg">
              {formatCurrency(total)}
            </td>
            {SHOW_PREVIOUS_YEAR && (
              <td className="py-3 text-right font-mono text-lg text-muted-foreground">
                {formatCurrency(0)}
              </td>
            )}
          </tr>
        </tfoot>
      </table>
    </div>
  )
}

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
            <Badge variant={selectedFiscalYear.closed ? 'secondary' : 'default'}>
              {selectedFiscalYear.closed
                ? 'Closed fiscal year'
                : 'Open fiscal year - balances may change'}
            </Badge>
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
              <BalanceSheetTable
                title="Aktiva (Assets)"
                sections={[
                  {
                    label: 'A. Anlagevermögen (Fixed Assets)',
                    accounts: balanceSheet.aktiva.anlagevermoegen,
                  },
                  {
                    label: 'B. Umlaufvermögen (Current Assets)',
                    accounts: balanceSheet.aktiva.umlaufvermoegen,
                  },
                ]}
                total={balanceSheet.aktiva.total}
              />

              {/* PASSIVA (Liabilities & Equity) */}
              <BalanceSheetTable
                title="Passiva (Liabilities & Equity)"
                sections={[
                  {
                    label: 'A. Eigenkapital (Equity)',
                    accounts: balanceSheet.passiva.eigenkapital,
                  },
                  {
                    label: 'B. Fremdkapital (Liabilities)',
                    accounts: balanceSheet.passiva.fremdkapital,
                  },
                ]}
                total={balanceSheet.passiva.total}
              />
            </div>
          </>
        )}
      </div>
    </AppLayout>
  )
}
