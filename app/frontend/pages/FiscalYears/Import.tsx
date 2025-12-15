import { useState } from 'react'
import { Head, Link, router } from '@inertiajs/react'
import { AppLayout } from '@/components/AppLayout'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { formatCurrency } from '@/utils/formatting'
import { ArrowLeft, Plus, Trash2, AlertCircle, CheckCircle, Save } from 'lucide-react'

interface AccountEntry {
  accountCode: string
  accountName: string
  balance: number
}

interface ImportProps {
  company: { id: number; name: string }
}

export default function FiscalYearImport({ company }: ImportProps) {
  const [year, setYear] = useState<string>('')
  const [anlagevermoegen, setAnlagevermoegen] = useState<AccountEntry[]>([])
  const [umlaufvermoegen, setUmlaufvermoegen] = useState<AccountEntry[]>([])
  const [eigenkapital, setEigenkapital] = useState<AccountEntry[]>([])
  const [fremdkapital, setFremdkapital] = useState<AccountEntry[]>([])

  const addAccountEntry = (
    setter: React.Dispatch<React.SetStateAction<AccountEntry[]>>
  ) => {
    setter((prev) => [...prev, { accountCode: '', accountName: '', balance: 0 }])
  }

  const removeAccountEntry = (
    setter: React.Dispatch<React.SetStateAction<AccountEntry[]>>,
    index: number
  ) => {
    setter((prev) => prev.filter((_, i) => i !== index))
  }

  const updateAccountEntry = (
    setter: React.Dispatch<React.SetStateAction<AccountEntry[]>>,
    index: number,
    field: keyof AccountEntry,
    value: string | number
  ) => {
    setter((prev) =>
      prev.map((entry, i) =>
        i === index ? { ...entry, [field]: value } : entry
      )
    )
  }

  const calculateTotal = (entries: AccountEntry[]) =>
    entries.reduce((sum, entry) => sum + (Number(entry.balance) || 0), 0)

  const aktivaTotal =
    calculateTotal(anlagevermoegen) + calculateTotal(umlaufvermoegen)
  const passivaTotal = calculateTotal(eigenkapital) + calculateTotal(fremdkapital)
  const balanced = Math.abs(aktivaTotal - passivaTotal) < 0.01

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()

    if (!year || year.length !== 4) {
      alert('Please enter a valid year (YYYY)')
      return
    }

    if (!balanced) {
      alert('Balance sheet does not balance. Aktiva must equal Passiva.')
      return
    }

    const balanceSheetData = {
      aktiva: {
        anlagevermoegen: anlagevermoegen.filter((e) => e.accountCode && e.balance),
        umlaufvermoegen: umlaufvermoegen.filter((e) => e.accountCode && e.balance),
        total: aktivaTotal,
      },
      passiva: {
        eigenkapital: eigenkapital.filter((e) => e.accountCode && e.balance),
        fremdkapital: fremdkapital.filter((e) => e.accountCode && e.balance),
        total: passivaTotal,
      },
      balanced: true,
    }

    router.post('/fiscal_years/import_create', {
      year,
      balance_sheet_data: JSON.stringify(balanceSheetData),
    })
  }

  const renderAccountSection = (
    title: string,
    entries: AccountEntry[],
    setter: React.Dispatch<React.SetStateAction<AccountEntry[]>>
  ) => (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <h4 className="font-semibold text-sm">{title}</h4>
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={() => addAccountEntry(setter)}
        >
          <Plus className="h-4 w-4 mr-1" />
          Add Account
        </Button>
      </div>

      {entries.length === 0 ? (
        <p className="text-sm text-muted-foreground italic">
          No accounts added yet
        </p>
      ) : (
        <div className="space-y-2">
          {entries.map((entry, index) => (
            <div key={index} className="grid grid-cols-12 gap-2 items-end">
              <div className="col-span-3">
                <Label className="text-xs">Account Code</Label>
                <Input
                  type="text"
                  value={entry.accountCode}
                  onChange={(e) =>
                    updateAccountEntry(setter, index, 'accountCode', e.target.value)
                  }
                  placeholder="e.g., 1200"
                />
              </div>
              <div className="col-span-5">
                <Label className="text-xs">Account Name</Label>
                <Input
                  type="text"
                  value={entry.accountName}
                  onChange={(e) =>
                    updateAccountEntry(setter, index, 'accountName', e.target.value)
                  }
                  placeholder="e.g., Bank"
                />
              </div>
              <div className="col-span-3">
                <Label className="text-xs">Balance (EUR)</Label>
                <Input
                  type="number"
                  step="0.01"
                  value={entry.balance}
                  onChange={(e) =>
                    updateAccountEntry(
                      setter,
                      index,
                      'balance',
                      parseFloat(e.target.value) || 0
                    )
                  }
                />
              </div>
              <div className="col-span-1">
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  onClick={() => removeAccountEntry(setter, index)}
                >
                  <Trash2 className="h-4 w-4 text-destructive" />
                </Button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )

  return (
    <AppLayout company={company} currentPage="fiscal-years">
      <Head title="Import Fiscal Year" />

      <div className="container mx-auto py-6 max-w-6xl">
        <div className="flex items-center gap-4 mb-6">
          <Link href="/fiscal_years">
            <Button variant="ghost" size="sm">
              <ArrowLeft className="mr-2 h-4 w-4" />
              Back to Fiscal Years
            </Button>
          </Link>
        </div>

        <div className="mb-6">
          <h1 className="text-3xl font-bold mb-2">Import Fiscal Year</h1>
          <p className="text-muted-foreground">
            Import a historical fiscal year by entering its closing balance sheet
            data. This is useful when you don't have transaction history but know the
            final balances.
          </p>
        </div>

        <Alert className="mb-6">
          <AlertCircle className="h-4 w-4" />
          <AlertDescription>
            This will create a closed fiscal year with a manual closing balance sheet.
            Make sure Aktiva equals Passiva before saving.
          </AlertDescription>
        </Alert>

        <form onSubmit={handleSubmit}>
          {/* Year Input */}
          <Card className="mb-6">
            <CardHeader>
              <CardTitle>Fiscal Year</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="max-w-xs">
                <Label htmlFor="year">Year (YYYY)</Label>
                <Input
                  id="year"
                  type="number"
                  value={year}
                  onChange={(e) => setYear(e.target.value)}
                  placeholder="e.g., 2023"
                  min="1900"
                  max="2100"
                  required
                />
              </div>
            </CardContent>
          </Card>

          {/* Balance Sheet Data */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
            {/* Aktiva (Assets) */}
            <Card>
              <CardHeader>
                <CardTitle>Aktiva (Assets)</CardTitle>
              </CardHeader>
              <CardContent className="space-y-6">
                {renderAccountSection(
                  'Anlagevermögen (Fixed Assets)',
                  anlagevermoegen,
                  setAnlagevermoegen
                )}
                {renderAccountSection(
                  'Umlaufvermögen (Current Assets)',
                  umlaufvermoegen,
                  setUmlaufvermoegen
                )}
                <div className="pt-4 border-t">
                  <div className="flex justify-between items-center">
                    <span className="font-semibold">Total Aktiva</span>
                    <span className="font-mono font-bold">
                      {formatCurrency(aktivaTotal)}
                    </span>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Passiva (Liabilities & Equity) */}
            <Card>
              <CardHeader>
                <CardTitle>Passiva (Liabilities & Equity)</CardTitle>
              </CardHeader>
              <CardContent className="space-y-6">
                {renderAccountSection(
                  'Eigenkapital (Equity)',
                  eigenkapital,
                  setEigenkapital
                )}
                {renderAccountSection(
                  'Fremdkapital (Liabilities)',
                  fremdkapital,
                  setFremdkapital
                )}
                <div className="pt-4 border-t">
                  <div className="flex justify-between items-center">
                    <span className="font-semibold">Total Passiva</span>
                    <span className="font-mono font-bold">
                      {formatCurrency(passivaTotal)}
                    </span>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Balance Validation */}
          {(aktivaTotal > 0 || passivaTotal > 0) && (
            <Alert
              className={`mb-6 ${
                balanced
                  ? 'border-green-200 bg-green-50'
                  : 'border-destructive bg-destructive/10'
              }`}
            >
              {balanced ? (
                <CheckCircle className="h-4 w-4 text-green-600" />
              ) : (
                <AlertCircle className="h-4 w-4 text-destructive" />
              )}
              <AlertDescription
                className={balanced ? 'text-green-800' : 'text-destructive'}
              >
                {balanced ? (
                  'Balance sheet is balanced. Aktiva equals Passiva.'
                ) : (
                  <>
                    Balance sheet does not balance. Difference:{' '}
                    {formatCurrency(Math.abs(aktivaTotal - passivaTotal))}
                  </>
                )}
              </AlertDescription>
            </Alert>
          )}

          {/* Action Buttons */}
          <div className="flex gap-3 justify-end">
            <Link href="/fiscal_years">
              <Button type="button" variant="outline">
                Cancel
              </Button>
            </Link>
            <Button type="submit" disabled={!balanced || !year}>
              <Save className="mr-2 h-4 w-4" />
              Import Fiscal Year
            </Button>
          </div>
        </form>
      </div>
    </AppLayout>
  )
}
