import { Head, Link, router } from '@inertiajs/react'
import { AppLayout } from '@/components/AppLayout'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { FiscalYearStatusBadge } from '@/components/FiscalYearStatusBadge'
import { formatDate, formatCurrency } from '@/utils/formatting'
import {
  FileText,
  Lock,
  Plus,
  CheckCircle2,
  AlertCircle,
  ArrowLeft,
} from 'lucide-react'

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

interface BalanceSheet {
  id: number
  sheetType: 'opening' | 'closing'
  source: 'manual' | 'calculated' | 'carryforward'
  balanceDate: string
  postedAt: string | null
  data: any
}

interface FiscalYearShowProps {
  company: { id: number; name: string }
  fiscalYear: FiscalYear
  openingBalance: BalanceSheet | null
  closingBalance: BalanceSheet | null
}

export default function FiscalYearShow({
  company,
  fiscalYear,
  openingBalance,
  closingBalance,
}: FiscalYearShowProps) {
  const handleClose = () => {
    if (
      confirm(
        `Are you sure you want to close fiscal year ${fiscalYear.year}? This action cannot be undone.`
      )
    ) {
      router.post(`/fiscal_years/${fiscalYear.id}/close`)
    }
  }

  const canClose =
    fiscalYear.workflowState === 'open_with_opening' && !fiscalYear.closed

  return (
    <AppLayout company={company} currentPage="fiscal-years">
      <Head title={`Fiscal Year ${fiscalYear.year}`} />

      <div className="container mx-auto py-6">
        <div className="flex items-center gap-4 mb-6">
          <Link href="/fiscal_years">
            <Button variant="ghost" size="sm">
              <ArrowLeft className="mr-2 h-4 w-4" />
              Back to Fiscal Years
            </Button>
          </Link>
        </div>

        <div className="mb-6">
          <div className="flex items-center gap-3 mb-2">
            <h1 className="text-3xl font-bold">Fiscal Year {fiscalYear.year}</h1>
            <FiscalYearStatusBadge workflowState={fiscalYear.workflowState} />
          </div>
          <p className="text-muted-foreground">
            {formatDate(fiscalYear.startDate)} - {formatDate(fiscalYear.endDate)}
          </p>
        </div>

        {/* Workflow Timeline */}
        <Card className="mb-6">
          <CardHeader>
            <CardTitle>Workflow Status</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              <div className="flex items-start gap-3">
                {fiscalYear.openingBalancePostedAt ? (
                  <CheckCircle2 className="h-5 w-5 text-green-500 mt-0.5" />
                ) : (
                  <AlertCircle className="h-5 w-5 text-yellow-500 mt-0.5" />
                )}
                <div className="flex-1">
                  <p className="font-medium">Opening Balance</p>
                  {fiscalYear.openingBalancePostedAt ? (
                    <p className="text-sm text-muted-foreground">
                      Posted on {formatDate(fiscalYear.openingBalancePostedAt)}
                    </p>
                  ) : (
                    <p className="text-sm text-muted-foreground">
                      Not yet posted
                    </p>
                  )}
                </div>
                {!fiscalYear.openingBalancePostedAt && (
                  <Link href={`/opening_balances/new?fiscal_year_id=${fiscalYear.id}`}>
                    <Button size="sm">
                      <Plus className="mr-2 h-4 w-4" />
                      Create Opening Balance
                    </Button>
                  </Link>
                )}
              </div>

              <div className="flex items-start gap-3">
                {fiscalYear.closingBalancePostedAt ? (
                  <CheckCircle2 className="h-5 w-5 text-green-500 mt-0.5" />
                ) : (
                  <AlertCircle className="h-5 w-5 text-muted-foreground mt-0.5" />
                )}
                <div className="flex-1">
                  <p className="font-medium">Closing Balance</p>
                  {fiscalYear.closingBalancePostedAt ? (
                    <p className="text-sm text-muted-foreground">
                      Posted on {formatDate(fiscalYear.closingBalancePostedAt)}
                    </p>
                  ) : (
                    <p className="text-sm text-muted-foreground">
                      Not yet posted
                    </p>
                  )}
                </div>
              </div>

              <div className="flex items-start gap-3">
                {fiscalYear.closed ? (
                  <Lock className="h-5 w-5 text-red-500 mt-0.5" />
                ) : (
                  <AlertCircle className="h-5 w-5 text-muted-foreground mt-0.5" />
                )}
                <div className="flex-1">
                  <p className="font-medium">Fiscal Year Closed</p>
                  {fiscalYear.closedAt ? (
                    <p className="text-sm text-muted-foreground">
                      Closed on {formatDate(fiscalYear.closedAt)}
                    </p>
                  ) : (
                    <p className="text-sm text-muted-foreground">Open</p>
                  )}
                </div>
                {canClose && (
                  <div className="flex gap-2">
                    <Link href={`/fiscal_years/${fiscalYear.id}/preview_closing`}>
                      <Button variant="outline" size="sm">
                        <FileText className="mr-2 h-4 w-4" />
                        Preview Closing
                      </Button>
                    </Link>
                    <Button
                      size="sm"
                      variant="destructive"
                      onClick={handleClose}
                    >
                      <Lock className="mr-2 h-4 w-4" />
                      Close Year
                    </Button>
                  </div>
                )}
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Opening Balance Sheet */}
        {openingBalance && (
          <Card className="mb-6">
            <CardHeader>
              <CardTitle>Opening Balance Sheet</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Source:</span>
                  <span className="font-medium capitalize">
                    {openingBalance.source}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Balance Date:</span>
                  <span className="font-medium">
                    {formatDate(openingBalance.balanceDate)}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Status:</span>
                  <span className="font-medium">
                    {openingBalance.postedAt ? 'Posted' : 'Draft'}
                  </span>
                </div>
                {openingBalance.data?.aktiva && (
                  <div className="flex justify-between pt-2 border-t">
                    <span className="text-muted-foreground">Total Assets:</span>
                    <span className="font-medium">
                      {formatCurrency(openingBalance.data.aktiva.total)}
                    </span>
                  </div>
                )}
              </div>
            </CardContent>
          </Card>
        )}

        {/* Closing Balance Sheet */}
        {closingBalance && (
          <Card>
            <CardHeader>
              <CardTitle>Closing Balance Sheet</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Source:</span>
                  <span className="font-medium capitalize">
                    {closingBalance.source}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Balance Date:</span>
                  <span className="font-medium">
                    {formatDate(closingBalance.balanceDate)}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Status:</span>
                  <span className="font-medium">
                    {closingBalance.postedAt ? 'Posted' : 'Draft'}
                  </span>
                </div>
                {closingBalance.data?.aktiva && (
                  <div className="flex justify-between pt-2 border-t">
                    <span className="text-muted-foreground">Total Assets:</span>
                    <span className="font-medium">
                      {formatCurrency(closingBalance.data.aktiva.total)}
                    </span>
                  </div>
                )}
              </div>
            </CardContent>
          </Card>
        )}

        {/* Quick Actions */}
        <div className="mt-6 flex gap-3">
          <Link href="/reports/balance_sheet">
            <Button variant="outline">
              <FileText className="mr-2 h-4 w-4" />
              View Balance Sheet Report
            </Button>
          </Link>
        </div>
      </div>
    </AppLayout>
  )
}
