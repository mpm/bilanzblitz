import { useState } from 'react'
import { Head, Link, router } from '@inertiajs/react'
import { AppLayout } from '@/components/AppLayout'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { RadioGroup, RadioGroupItem } from '@/components/ui/radio-group'
import { Label } from '@/components/ui/label'
import { ArrowLeft, AlertCircle, FileText, Upload } from 'lucide-react'

interface FiscalYear {
  id: number
  year: number
  startDate: string
  endDate: string
}

interface PreviousFiscalYear {
  id: number
  year: number
  hasClosingBalance: boolean
}

interface OpeningBalanceFormProps {
  company: { id: number; name: string }
  fiscalYear: FiscalYear
  previousFiscalYear: PreviousFiscalYear | null
}

export default function OpeningBalanceForm({
  company,
  fiscalYear,
  previousFiscalYear,
}: OpeningBalanceFormProps) {
  const [source, setSource] = useState<'manual' | 'carryforward'>(
    previousFiscalYear?.hasClosingBalance ? 'carryforward' : 'manual'
  )

  const handleCarryforward = () => {
    if (
      confirm(
        `Import opening balance from fiscal year ${previousFiscalYear?.year}?\n\nThis will create an opening balance based on the previous year's closing balance.`
      )
    ) {
      router.post('/opening_balances', {
        fiscal_year_id: fiscalYear.id,
        source: 'carryforward',
      })
    }
  }

  return (
    <AppLayout company={company} currentPage="reports">
      <Head title={`Create Opening Balance - ${fiscalYear.year}`} />

      <div className="container mx-auto py-6 max-w-4xl">
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
            Create Opening Balance
          </h1>
          <p className="text-muted-foreground">
            Fiscal Year {fiscalYear.year} - {company.name}
          </p>
        </div>

        <Alert className="mb-6">
          <AlertCircle className="h-4 w-4" />
          <AlertDescription>
            An opening balance (Eröffnungsbilanz) is required before you can create
            journal entries for this fiscal year. Choose how you would like to
            create the opening balance.
          </AlertDescription>
        </Alert>

        <Card className="mb-6">
          <CardHeader>
            <CardTitle>Select Method</CardTitle>
          </CardHeader>
          <CardContent>
            <RadioGroup
              value={source}
              onValueChange={(value: string) =>
                setSource(value as 'manual' | 'carryforward')
              }
            >
              <div className="space-y-4">
                {/* Carryforward Option */}
                {previousFiscalYear?.hasClosingBalance && (
                  <div className="flex items-start space-x-3 border rounded-lg p-4">
                    <RadioGroupItem value="carryforward" id="carryforward" />
                    <div className="flex-1">
                      <Label htmlFor="carryforward" className="cursor-pointer">
                        <div className="font-semibold mb-1">
                          Import from Previous Year (Recommended)
                        </div>
                        <p className="text-sm text-muted-foreground">
                          Automatically import the closing balance from fiscal year{' '}
                          {previousFiscalYear.year} as the opening balance for{' '}
                          {fiscalYear.year}. This is the standard approach for
                          continuing operations.
                        </p>
                      </Label>
                    </div>
                  </div>
                )}

                {/* Manual Entry Option */}
                <div className="flex items-start space-x-3 border rounded-lg p-4">
                  <RadioGroupItem value="manual" id="manual" />
                  <div className="flex-1">
                    <Label htmlFor="manual" className="cursor-pointer">
                      <div className="font-semibold mb-1">
                        Manual Entry
                      </div>
                      <p className="text-sm text-muted-foreground">
                        {previousFiscalYear?.hasClosingBalance
                          ? 'Manually enter opening balance data. Use this if you need to make adjustments or corrections.'
                          : 'Manually enter opening balance data. This is typically used for the first fiscal year of a company or when importing historical data.'}
                      </p>
                    </Label>
                  </div>
                </div>
              </div>
            </RadioGroup>
          </CardContent>
        </Card>

        {/* Action Buttons */}
        <div className="flex gap-3 justify-end">
          <Link href={`/fiscal_years/${fiscalYear.id}`}>
            <Button variant="outline">Cancel</Button>
          </Link>

          {source === 'carryforward' ? (
            <Button onClick={handleCarryforward}>
              <Upload className="mr-2 h-4 w-4" />
              Import from {previousFiscalYear?.year}
            </Button>
          ) : (
            <Button disabled>
              <FileText className="mr-2 h-4 w-4" />
              Manual Entry (Coming Soon)
            </Button>
          )}
        </div>

        {source === 'manual' && (
          <Alert variant="default" className="mt-6">
            <AlertCircle className="h-4 w-4" />
            <AlertDescription>
              The manual entry interface is under development. For now, you can
              create opening balances by importing from the previous fiscal year
              or by creating journal entries directly with entry_type='opening'.
            </AlertDescription>
          </Alert>
        )}
      </div>
    </AppLayout>
  )
}
