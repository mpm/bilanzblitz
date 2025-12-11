import { Head, router } from '@inertiajs/react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import {
  LayoutDashboard,
  Building2,
  Calendar,
  Wallet,
  FileText,
  BarChart3,
  Settings,
  LogOut,
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
  const handleLogout = () => {
    router.delete('/users/sign_out')
  }

  return (
    <div className="min-h-screen bg-background">
      <Head title={`Dashboard - ${company.name}`} />

      {/* Top Navigation - Stripe style */}
      <header className="sticky top-0 z-50 w-full border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
        <div className="flex h-14 items-center px-4 sm:px-6">
          <div className="flex items-center gap-4 flex-1">
            <h1 className="text-lg font-semibold tracking-tight">
              Bilanz<span className="text-primary">Blitz</span>
            </h1>
            <div className="h-4 w-px bg-border" />
            <div className="flex items-center gap-2 text-sm text-muted-foreground">
              <Building2 className="h-4 w-4" />
              <span className="font-medium text-foreground">{company.name}</span>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <Button variant="ghost" size="icon" className="h-8 w-8">
              <Settings className="h-4 w-4" />
            </Button>
            <Button variant="ghost" size="icon" className="h-8 w-8" onClick={handleLogout}>
              <LogOut className="h-4 w-4" />
            </Button>
          </div>
        </div>
      </header>

      <div className="flex">
        {/* Sidebar - Stripe style */}
        <aside className="sticky top-14 hidden h-[calc(100vh-3.5rem)] w-64 flex-col border-r bg-background lg:flex">
          <nav className="flex-1 space-y-1 p-4">
            <Button
              variant="secondary"
              className="w-full justify-start gap-3 font-normal"
            >
              <LayoutDashboard className="h-4 w-4" />
              Dashboard
            </Button>
            <Button
              variant="ghost"
              className="w-full justify-start gap-3 font-normal text-muted-foreground"
              disabled
            >
              <FileText className="h-4 w-4" />
              Journal Entries
            </Button>
            <Button
              variant="ghost"
              className="w-full justify-start gap-3 font-normal text-muted-foreground"
              disabled
            >
              <Wallet className="h-4 w-4" />
              Bank Accounts
            </Button>
            <Button
              variant="ghost"
              className="w-full justify-start gap-3 font-normal text-muted-foreground"
              disabled
            >
              <FileText className="h-4 w-4" />
              Documents
            </Button>
            <Button
              variant="ghost"
              className="w-full justify-start gap-3 font-normal text-muted-foreground"
              disabled
            >
              <BarChart3 className="h-4 w-4" />
              Reports
            </Button>
          </nav>
        </aside>

        {/* Main Content */}
        <main className="flex-1">
          <div className="mx-auto max-w-7xl p-4 sm:p-6 lg:p-8">
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
          </div>
        </main>
      </div>
    </div>
  )
}
