import { useState } from 'react'
import { Head, Link, router } from '@inertiajs/react'
import { AppLayout } from '@/components/AppLayout'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Label } from '@/components/ui/label'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { ArrowLeft, Calendar, AlertCircle, CheckCircle } from 'lucide-react'

interface NewFiscalYearProps {
  company: { id: number; name: string }
  availableYears: number[]
}

export default function NewFiscalYear({
  company,
  availableYears,
}: NewFiscalYearProps) {
  const [selectedYear, setSelectedYear] = useState<string>(
    availableYears.length > 0 ? availableYears[0].toString() : ''
  )
  const [isSubmitting, setIsSubmitting] = useState(false)

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()

    if (!selectedYear) {
      alert('Please select a year')
      return
    }

    setIsSubmitting(true)
    router.post('/fiscal_years', { year: selectedYear })
  }

  return (
    <AppLayout company={company} currentPage="fiscal-years">
      <Head title="Create Fiscal Year" />

      <div className="container mx-auto py-6 max-w-3xl">
        <div className="flex items-center gap-4 mb-6">
          <Link href="/fiscal_years">
            <Button variant="ghost" size="sm">
              <ArrowLeft className="mr-2 h-4 w-4" />
              Back to Fiscal Years
            </Button>
          </Link>
        </div>

        <div className="mb-6">
          <h1 className="text-3xl font-bold mb-2">Create Fiscal Year</h1>
          <p className="text-muted-foreground">
            Create a new fiscal year to start recording transactions.
          </p>
        </div>

        {availableYears.length === 0 ? (
          <Alert variant="destructive" className="mb-6">
            <AlertCircle className="h-4 w-4" />
            <AlertDescription>
              No years available to create. All fiscal years up to the current
              year already exist.
            </AlertDescription>
          </Alert>
        ) : (
          <>
            <Alert className="mb-6 border-blue-200 bg-blue-50">
              <AlertCircle className="h-4 w-4 text-blue-600" />
              <AlertDescription className="text-blue-800">
                <strong>Automatic Opening Balance:</strong> If the previous year
                is closed, the opening balance will be automatically carried
                forward from the previous year's closing balance.
              </AlertDescription>
            </Alert>

            <form onSubmit={handleSubmit}>
              <Card className="mb-6">
                <CardHeader>
                  <CardTitle>Select Fiscal Year</CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="space-y-4">
                    <div>
                      <Label htmlFor="year">Year</Label>
                      <select
                        id="year"
                        value={selectedYear}
                        onChange={(e) => setSelectedYear(e.target.value)}
                        className="w-full mt-1 px-3 py-2 border border-input bg-background rounded-md focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2"
                        required
                      >
                        {availableYears.map((year) => (
                          <option key={year} value={year}>
                            {year}
                          </option>
                        ))}
                      </select>
                      <p className="text-sm text-muted-foreground mt-2">
                        Select the year for the new fiscal year (January 1 -
                        December 31)
                      </p>
                    </div>

                    {selectedYear && (
                      <Alert className="border-green-200 bg-green-50">
                        <CheckCircle className="h-4 w-4 text-green-600" />
                        <AlertDescription className="text-green-800">
                          <strong>Fiscal Year {selectedYear}</strong>
                          <br />
                          Period: January 1, {selectedYear} - December 31,{' '}
                          {selectedYear}
                        </AlertDescription>
                      </Alert>
                    )}
                  </div>
                </CardContent>
              </Card>

              <div className="flex gap-3 justify-end">
                <Link href="/fiscal_years">
                  <Button type="button" variant="outline" disabled={isSubmitting}>
                    Cancel
                  </Button>
                </Link>
                <Button type="submit" disabled={!selectedYear || isSubmitting}>
                  <Calendar className="mr-2 h-4 w-4" />
                  {isSubmitting ? 'Creating...' : 'Create Fiscal Year'}
                </Button>
              </div>
            </form>
          </>
        )}
      </div>
    </AppLayout>
  )
}
