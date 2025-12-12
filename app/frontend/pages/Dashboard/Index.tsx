import { Head } from '@inertiajs/react'
import { AppLayout } from '@/components/AppLayout'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import {
  Building2,
  Calendar,
  Wallet,
  FileText,
  BarChart3,
  ChevronRight
} from 'lucide-react'

interface DashboardProps {
  company: {
    id: number
    name: string
  }
  fiscalYear: {
    id: number
    year: number
    startDate: string
    endDate: string
  } | null
  bankAccount: {
    id: number
    bankName: string
    currency: string
  } | null
}

export default function Dashboard({ company, fiscalYear, bankAccount }: DashboardProps) {
  return (
    <AppLayout company={company} currentPage="dashboard">
      <Head title={`Dashboard - ${company.name}`} />
            {/* Welcome Header */}
            <div className="mb-8">
              <h2 className="text-2xl font-semibold tracking-tight mb-1">
                Welcome back
              </h2>
              <p className="text-sm text-muted-foreground">
                Here's what's happening with your company
              </p>
            </div>

            {/* Stats Grid - Stripe style */}
            <div className="grid gap-4 md:grid-cols-3 mb-8">
              <Card>
                <CardHeader className="flex flex-row items-center justify-between pb-2 space-y-0">
                  <CardTitle className="text-sm font-medium text-muted-foreground">
                    Company
                  </CardTitle>
                  <Building2 className="h-4 w-4 text-muted-foreground" />
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-semibold">{company.name}</div>
                  <p className="text-xs text-muted-foreground mt-1">
                    Active company
                  </p>
                </CardContent>
              </Card>

              {fiscalYear && (
                <Card>
                  <CardHeader className="flex flex-row items-center justify-between pb-2 space-y-0">
                    <CardTitle className="text-sm font-medium text-muted-foreground">
                      Fiscal Year
                    </CardTitle>
                    <Calendar className="h-4 w-4 text-muted-foreground" />
                  </CardHeader>
                  <CardContent>
                    <div className="text-2xl font-semibold">{fiscalYear.year}</div>
                    <p className="text-xs text-muted-foreground mt-1">
                      {new Date(fiscalYear.startDate).toLocaleDateString('de-DE')} -{' '}
                      {new Date(fiscalYear.endDate).toLocaleDateString('de-DE')}
                    </p>
                  </CardContent>
                </Card>
              )}

              {bankAccount && (
                <Card>
                  <CardHeader className="flex flex-row items-center justify-between pb-2 space-y-0">
                    <CardTitle className="text-sm font-medium text-muted-foreground">
                      Bank Account
                    </CardTitle>
                    <Wallet className="h-4 w-4 text-muted-foreground" />
                  </CardHeader>
                  <CardContent>
                    <div className="text-2xl font-semibold">{bankAccount.currency}</div>
                    <p className="text-xs text-muted-foreground mt-1">
                      {bankAccount.bankName}
                    </p>
                  </CardContent>
                </Card>
              )}
            </div>

            {/* Quick Actions - Stripe style */}
            <Card className="mb-8">
              <CardHeader>
                <CardTitle>Quick actions</CardTitle>
                <CardDescription>
                  Get started with these common tasks
                </CardDescription>
              </CardHeader>
              <CardContent className="grid gap-3">
                <button
                  disabled
                  className="flex items-center justify-between rounded-lg border p-4 text-left transition-colors hover:bg-accent disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <div className="flex items-center gap-3">
                    <div className="rounded-full bg-primary/10 p-2">
                      <FileText className="h-4 w-4 text-primary" />
                    </div>
                    <div>
                      <div className="font-medium">Create journal entry</div>
                      <div className="text-sm text-muted-foreground">
                        Record a new transaction
                      </div>
                    </div>
                  </div>
                  <ChevronRight className="h-5 w-5 text-muted-foreground" />
                </button>

                <button
                  disabled
                  className="flex items-center justify-between rounded-lg border p-4 text-left transition-colors hover:bg-accent disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <div className="flex items-center gap-3">
                    <div className="rounded-full bg-primary/10 p-2">
                      <Wallet className="h-4 w-4 text-primary" />
                    </div>
                    <div>
                      <div className="font-medium">Add bank account</div>
                      <div className="text-sm text-muted-foreground">
                        Connect a real bank account
                      </div>
                    </div>
                  </div>
                  <ChevronRight className="h-5 w-5 text-muted-foreground" />
                </button>

                <button
                  disabled
                  className="flex items-center justify-between rounded-lg border p-4 text-left transition-colors hover:bg-accent disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <div className="flex items-center gap-3">
                    <div className="rounded-full bg-primary/10 p-2">
                      <BarChart3 className="h-4 w-4 text-primary" />
                    </div>
                    <div>
                      <div className="font-medium">Generate VAT report</div>
                      <div className="text-sm text-muted-foreground">
                        Create a tax report for filing
                      </div>
                    </div>
                  </div>
                  <ChevronRight className="h-5 w-5 text-muted-foreground" />
                </button>
              </CardContent>
            </Card>

            {/* Coming Soon Card */}
            <Card>
              <CardHeader>
                <CardTitle>Dashboard features coming soon</CardTitle>
                <CardDescription>
                  We're building out your complete accounting dashboard
                </CardDescription>
              </CardHeader>
              <CardContent>
                <ul className="space-y-2 text-sm text-muted-foreground">
                  <li className="flex items-start gap-2">
                    <div className="rounded-full bg-primary/10 p-1 mt-0.5">
                      <div className="h-1.5 w-1.5 rounded-full bg-primary" />
                    </div>
                    <span>Financial overview with key metrics and charts</span>
                  </li>
                  <li className="flex items-start gap-2">
                    <div className="rounded-full bg-primary/10 p-1 mt-0.5">
                      <div className="h-1.5 w-1.5 rounded-full bg-primary" />
                    </div>
                    <span>Recent transactions and activity feed</span>
                  </li>
                  <li className="flex items-start gap-2">
                    <div className="rounded-full bg-primary/10 p-1 mt-0.5">
                      <div className="h-1.5 w-1.5 rounded-full bg-primary" />
                    </div>
                    <span>Automated bank transaction reconciliation</span>
                  </li>
                  <li className="flex items-start gap-2">
                    <div className="rounded-full bg-primary/10 p-1 mt-0.5">
                      <div className="h-1.5 w-1.5 rounded-full bg-primary" />
                    </div>
                    <span>Document upload with OCR for automatic data extraction</span>
                  </li>
                  <li className="flex items-start gap-2">
                    <div className="rounded-full bg-primary/10 p-1 mt-0.5">
                      <div className="h-1.5 w-1.5 rounded-full bg-primary" />
                    </div>
                    <span>One-click VAT reports and annual tax returns</span>
                  </li>
                </ul>
              </CardContent>
            </Card>
    </AppLayout>
  )
}
