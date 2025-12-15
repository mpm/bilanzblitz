import React from 'react'
import { Head, Link, router } from '@inertiajs/react'
import { AppLayout } from '@/components/AppLayout'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { formatCurrency } from '@/utils/formatting'
import { ArrowLeft, Lock, AlertCircle, CheckCircle } from 'lucide-react'

interface FiscalYear {
  id: number
  year: number
  startDate: string
  endDate: string
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

interface PreviewClosingProps {
  company: { id: number; name: string }
  fiscalYear: FiscalYear
  balanceSheet: BalanceSheetData
}

export default function PreviewClosing({
  company,
  fiscalYear,
  balanceSheet,
}: PreviewClosingProps) {
  // Use React Fragment to group JSX
  const handleConfirmClose = () => {
    if (
      confirm(
        `Are you sure you want to close fiscal year ${fiscalYear.year}?\n\nThis will:\n- Create closing journal entries (SBK)\n- Mark the fiscal year as closed\n- Create opening balance for ${fiscalYear.year + 1}\n\nThis action cannot be undone.`
      )
    ) {
      router.post(`/fiscal_years/${fiscalYear.id}/close`)
    }
  }

  const renderAccountTable = (
    title: string,
    sections: Array<{ label: string; accounts: AccountBalance[] }>,
    total: number
  ) => (
    <div className="mb-6">
      <h3 className="text-lg font-semibold mb-3">{title}</h3>
      <table className="w-full">
        <thead>
          <tr className="border-b-2 border-border">
            <th className="text-left py-2 font-semibold text-sm">Account</th>
            <th className="text-right py-2 font-semibold text-sm w-32">
              Balance
            </th>
          </tr>
        </thead>
        <tbody>
          {sections.map((section) => (
            <React.Fragment key={section.label}>
              {section.accounts.length > 0 && (
                <>
                  <tr>
                    <td
                      colSpan={2}
                      className="pt-4 pb-2 font-semibold text-sm text-muted-foreground"
                    >
                      {section.label}
                    </td>
                  </tr>
                  {section.accounts.map((account) => (
                    <tr key={account.accountCode} className="border-b">
                      <td className="py-2 text-sm">
                        <div>
                          <span className="font-medium">{account.accountCode}</span>{' '}
                          {account.accountName}
                        </div>
                      </td>
                      <td className="py-2 text-sm text-right font-mono">
                        {formatCurrency(account.balance)}
                      </td>
                    </tr>
                  ))}
                </>
              )}
            </React.Fragment>
          ))}
          <tr className="border-t-2 border-border font-bold">
            <td className="py-3 text-sm">Total {title}</td>
            <td className="py-3 text-sm text-right font-mono">
              {formatCurrency(total)}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  )

  return (
    <AppLayout company={company} currentPage="reports">
      <Head title={`Preview Closing - Fiscal Year ${fiscalYear.year}`} />

      <div className="container mx-auto py-6 max-w-6xl">
        <div className="flex items-center gap-4 mb-6">
          <Link href={`/fiscal_years/${fiscalYear.id}`}>
            <Button variant="ghost" size="sm">
              <ArrowLeft className="mr-2 h-4 w-4" />
              Back to Fiscal Year
            </Button>
          </Link>
        </div>

        <div className="mb-6">
          <h1 className="text-3xl font-bold mb-2">
            Preview Closing Balance - Fiscal Year {fiscalYear.year}
          </h1>
          <p className="text-muted-foreground">
            Review the closing balance sheet before finalizing the fiscal year.
          </p>
        </div>

        {/* Balance Validation Alert */}
        {balanceSheet.balanced ? (
          <Alert className="mb-6 border-green-200 bg-green-50">
            <CheckCircle className="h-4 w-4 text-green-600" />
            <AlertDescription className="text-green-800">
              Balance sheet is balanced. Aktiva equals Passiva.
            </AlertDescription>
          </Alert>
        ) : (
          <Alert variant="destructive" className="mb-6">
            <AlertCircle className="h-4 w-4" />
            <AlertDescription>
              Warning: Balance sheet does not balance. Aktiva (
              {formatCurrency(balanceSheet.aktiva.total)}) does not equal Passiva
              ({formatCurrency(balanceSheet.passiva.total)}). Please review your
              journal entries before closing.
            </AlertDescription>
          </Alert>
        )}

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Aktiva (Assets) */}
          <Card>
            <CardHeader>
              <CardTitle>Aktiva (Assets)</CardTitle>
            </CardHeader>
            <CardContent>
              {renderAccountTable(
                'Aktiva',
                [
                  {
                    label: 'Anlagevermögen (Fixed Assets)',
                    accounts: balanceSheet.aktiva.anlagevermoegen,
                  },
                  {
                    label: 'Umlaufvermögen (Current Assets)',
                    accounts: balanceSheet.aktiva.umlaufvermoegen,
                  },
                ],
                balanceSheet.aktiva.total
              )}
            </CardContent>
          </Card>

          {/* Passiva (Liabilities & Equity) */}
          <Card>
            <CardHeader>
              <CardTitle>Passiva (Liabilities & Equity)</CardTitle>
            </CardHeader>
            <CardContent>
              {renderAccountTable(
                'Passiva',
                [
                  {
                    label: 'Eigenkapital (Equity)',
                    accounts: balanceSheet.passiva.eigenkapital,
                  },
                  {
                    label: 'Fremdkapital (Liabilities)',
                    accounts: balanceSheet.passiva.fremdkapital,
                  },
                ],
                balanceSheet.passiva.total
              )}
            </CardContent>
          </Card>
        </div>

        {/* Action Buttons */}
        <div className="mt-6 flex gap-3 justify-end">
          <Link href={`/fiscal_years/${fiscalYear.id}`}>
            <Button variant="outline">Cancel</Button>
          </Link>
          <Button
            variant="destructive"
            onClick={handleConfirmClose}
            disabled={!balanceSheet.balanced}
          >
            <Lock className="mr-2 h-4 w-4" />
            Confirm Close Fiscal Year
          </Button>
        </div>

        {!balanceSheet.balanced && (
          <Alert variant="destructive" className="mt-6">
            <AlertCircle className="h-4 w-4" />
            <AlertDescription>
              The fiscal year cannot be closed until the balance sheet balances.
            </AlertDescription>
          </Alert>
        )}
      </div>
    </AppLayout>
  )
}
