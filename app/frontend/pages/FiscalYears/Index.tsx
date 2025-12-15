import { Head, Link } from '@inertiajs/react'
import { AppLayout } from '@/components/AppLayout'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { FiscalYearStatusBadge } from '@/components/FiscalYearStatusBadge'
import { formatDate } from '@/utils/formatting'
import { Calendar, Eye } from 'lucide-react'

interface FiscalYear {
  id: number
  year: number
  startDate: string
  endDate: string
  closed: boolean
  closedAt: string | null
  openingBalancePostedAt: string | null
  closingBalancePostedAt: string | null
  workflowState: 'open' | 'open_with_opening' | 'closing_posted' | 'closed'
}

interface FiscalYearsIndexProps {
  company: { id: number; name: string }
  fiscalYears: FiscalYear[]
}

export default function FiscalYearsIndex({
  company,
  fiscalYears,
}: FiscalYearsIndexProps) {
  return (
    <AppLayout company={company} currentPage="fiscal-years">
      <Head title="Fiscal Years" />

      <div className="container mx-auto py-6">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-3xl font-bold">Fiscal Years</h1>
            <p className="text-muted-foreground mt-1">
              Manage fiscal years for {company.name}
            </p>
          </div>
        </div>

        {fiscalYears.length === 0 ? (
          <Card>
            <CardContent className="py-12 text-center">
              <Calendar className="mx-auto h-12 w-12 text-muted-foreground mb-4" />
              <h3 className="text-lg font-semibold mb-2">No fiscal years found</h3>
              <p className="text-muted-foreground mb-4">
                Fiscal years are created automatically when you create journal entries.
              </p>
            </CardContent>
          </Card>
        ) : (
          <div className="space-y-4">
            {fiscalYears.map((fiscalYear) => (
              <Card key={fiscalYear.id}>
                <CardHeader>
                  <div className="flex items-start justify-between">
                    <div className="flex-1">
                      <div className="flex items-center gap-3">
                        <CardTitle className="text-2xl">
                          Fiscal Year {fiscalYear.year}
                        </CardTitle>
                        <FiscalYearStatusBadge
                          workflowState={fiscalYear.workflowState}
                        />
                      </div>
                      <div className="text-sm text-muted-foreground mt-2 space-y-1">
                        <p>
                          Period: {formatDate(fiscalYear.startDate)} -{' '}
                          {formatDate(fiscalYear.endDate)}
                        </p>
                        {fiscalYear.openingBalancePostedAt && (
                          <p>
                            Opening balance posted:{' '}
                            {formatDate(fiscalYear.openingBalancePostedAt)}
                          </p>
                        )}
                        {fiscalYear.closingBalancePostedAt && (
                          <p>
                            Closing balance posted:{' '}
                            {formatDate(fiscalYear.closingBalancePostedAt)}
                          </p>
                        )}
                        {fiscalYear.closedAt && (
                          <p>Closed: {formatDate(fiscalYear.closedAt)}</p>
                        )}
                      </div>
                    </div>
                    <Link href={`/fiscal_years/${fiscalYear.id}`}>
                      <Button variant="outline" size="sm">
                        <Eye className="mr-2 h-4 w-4" />
                        View Details
                      </Button>
                    </Link>
                  </div>
                </CardHeader>
              </Card>
            ))}
          </div>
        )}
      </div>
    </AppLayout>
  )
}
