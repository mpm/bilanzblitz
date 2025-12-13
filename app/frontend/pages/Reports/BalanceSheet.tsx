import { Head, router } from '@inertiajs/react'
import { AppLayout } from '@/components/AppLayout'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
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

const AccountTable = ({ accounts }: { accounts: AccountBalance[] }) => {
  if (accounts.length === 0) {
    return (
      <div className="text-center py-6 text-muted-foreground text-sm">
        No accounts with balances
      </div>
    )
  }

  return (
    <div className="space-y-2">
      {accounts.map((account) => (
        <div
          key={account.accountCode}
          className="flex justify-between items-center py-2 px-3 rounded-md hover:bg-accent/50 transition-colors"
        >
          <div className="flex items-center gap-2">
            <span className="font-mono text-sm text-muted-foreground">
              {account.accountCode}
            </span>
            <span className="text-sm">{account.accountName}</span>
          </div>
          <span className="font-mono text-sm font-medium">
            {formatCurrency(account.balance)}
          </span>
        </div>
      ))}
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

            {/* Two-Column Layout */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              {/* AKTIVA (Assets) */}
              <div className="space-y-4">
                <h2 className="text-2xl font-semibold">Aktiva (Assets)</h2>

                {/* Fixed Assets */}
                <Card>
                  <CardHeader>
                    <CardTitle className="text-lg">
                      A. Anlagevermögen (Fixed Assets)
                    </CardTitle>
                  </CardHeader>
                  <CardContent>
                    <AccountTable accounts={balanceSheet.aktiva.anlagevermoegen} />
                  </CardContent>
                </Card>

                {/* Current Assets */}
                <Card>
                  <CardHeader>
                    <CardTitle className="text-lg">
                      B. Umlaufvermögen (Current Assets)
                    </CardTitle>
                  </CardHeader>
                  <CardContent>
                    <AccountTable accounts={balanceSheet.aktiva.umlaufvermoegen} />
                  </CardContent>
                </Card>

                {/* Total Aktiva */}
                <Card className="bg-primary/5 border-primary/20">
                  <CardContent className="pt-6">
                    <div className="flex justify-between items-center">
                      <span className="text-lg font-semibold">Total Assets</span>
                      <span className="text-2xl font-bold font-mono">
                        {formatCurrency(balanceSheet.aktiva.total)}
                      </span>
                    </div>
                  </CardContent>
                </Card>
              </div>

              {/* PASSIVA (Liabilities & Equity) */}
              <div className="space-y-4">
                <h2 className="text-2xl font-semibold">
                  Passiva (Liabilities & Equity)
                </h2>

                {/* Equity */}
                <Card>
                  <CardHeader>
                    <CardTitle className="text-lg">
                      A. Eigenkapital (Equity)
                    </CardTitle>
                  </CardHeader>
                  <CardContent>
                    <AccountTable accounts={balanceSheet.passiva.eigenkapital} />
                  </CardContent>
                </Card>

                {/* Liabilities */}
                <Card>
                  <CardHeader>
                    <CardTitle className="text-lg">
                      B. Fremdkapital (Liabilities)
                    </CardTitle>
                  </CardHeader>
                  <CardContent>
                    <AccountTable accounts={balanceSheet.passiva.fremdkapital} />
                  </CardContent>
                </Card>

                {/* Total Passiva */}
                <Card className="bg-primary/5 border-primary/20">
                  <CardContent className="pt-6">
                    <div className="flex justify-between items-center">
                      <span className="text-lg font-semibold">
                        Total Liabilities & Equity
                      </span>
                      <span className="text-2xl font-bold font-mono">
                        {formatCurrency(balanceSheet.passiva.total)}
                      </span>
                    </div>
                  </CardContent>
                </Card>
              </div>
            </div>
          </>
        )}
      </div>
    </AppLayout>
  )
}
