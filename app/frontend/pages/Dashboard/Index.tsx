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
  Plus
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

      {/* Top Navigation */}
      <nav className="border-b border-border bg-card">
        <div className="max-w-7xl mx-auto px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center gap-3">
              <div className="text-2xl font-bold" style={{ fontFamily: 'var(--font-display)' }}>
                Bilanz<span className="text-primary">Blitz</span>
              </div>
              <div className="h-6 w-px bg-border" />
              <div className="flex items-center gap-2 text-muted-foreground">
                <Building2 className="h-4 w-4" />
                <span style={{ fontFamily: 'var(--font-body)' }}>{company.name}</span>
              </div>
            </div>

            <div className="flex items-center gap-2">
              <Button variant="ghost" size="icon">
                <Settings className="h-5 w-5" />
              </Button>
              <Button variant="ghost" size="icon" onClick={handleLogout}>
                <LogOut className="h-5 w-5" />
              </Button>
            </div>
          </div>
        </div>
      </nav>

      {/* Sidebar + Main Content */}
      <div className="flex">
        {/* Sidebar */}
        <aside className="w-64 border-r border-border bg-card min-h-[calc(100vh-4rem)] p-4">
          <nav className="space-y-1">
            <Button
              variant="secondary"
              className="w-full justify-start gap-3"
              style={{ fontFamily: 'var(--font-body)' }}
            >
              <LayoutDashboard className="h-5 w-5" />
              Dashboard
            </Button>
            <Button
              variant="ghost"
              className="w-full justify-start gap-3"
              style={{ fontFamily: 'var(--font-body)' }}
              disabled
            >
              <FileText className="h-5 w-5" />
              Journal Entries
            </Button>
            <Button
              variant="ghost"
              className="w-full justify-start gap-3"
              style={{ fontFamily: 'var(--font-body)' }}
              disabled
            >
              <Wallet className="h-5 w-5" />
              Bank Accounts
            </Button>
            <Button
              variant="ghost"
              className="w-full justify-start gap-3"
              style={{ fontFamily: 'var(--font-body)' }}
              disabled
            >
              <FileText className="h-5 w-5" />
              Documents
            </Button>
            <Button
              variant="ghost"
              className="w-full justify-start gap-3"
              style={{ fontFamily: 'var(--font-body)' }}
              disabled
            >
              <BarChart3 className="h-5 w-5" />
              Reports
            </Button>
          </nav>
        </aside>

        {/* Main Content */}
        <main className="flex-1 p-8">
          <div className="max-w-7xl mx-auto">
            {/* Welcome Header */}
            <div className="mb-8">
              <h1
                className="text-4xl font-bold mb-2"
                style={{ fontFamily: 'var(--font-display)' }}
              >
                Welcome to Your Dashboard
              </h1>
              <p
                className="text-muted-foreground text-lg"
                style={{ fontFamily: 'var(--font-body)' }}
              >
                Your company is set up and ready to go!
              </p>
            </div>

            {/* Info Cards */}
            <div className="grid md:grid-cols-3 gap-6 mb-8">
              <Card>
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                  <CardTitle className="text-sm font-medium">Company</CardTitle>
                  <Building2 className="h-4 w-4 text-muted-foreground" />
                </CardHeader>
                <CardContent>
                  <div
                    className="text-2xl font-bold"
                    style={{ fontFamily: 'var(--font-display)' }}
                  >
                    {company.name}
                  </div>
                  <p className="text-xs text-muted-foreground mt-1">
                    Active company
                  </p>
                </CardContent>
              </Card>

              {fiscalYear && (
                <Card>
                  <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                    <CardTitle className="text-sm font-medium">Fiscal Year</CardTitle>
                    <Calendar className="h-4 w-4 text-muted-foreground" />
                  </CardHeader>
                  <CardContent>
                    <div
                      className="text-2xl font-bold"
                      style={{ fontFamily: 'var(--font-display)' }}
                    >
                      {fiscalYear.year}
                    </div>
                    <p className="text-xs text-muted-foreground mt-1">
                      {new Date(fiscalYear.startDate).toLocaleDateString('de-DE')} - {new Date(fiscalYear.endDate).toLocaleDateString('de-DE')}
                    </p>
                  </CardContent>
                </Card>
              )}

              {bankAccount && (
                <Card>
                  <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                    <CardTitle className="text-sm font-medium">Bank Account</CardTitle>
                    <Wallet className="h-4 w-4 text-muted-foreground" />
                  </CardHeader>
                  <CardContent>
                    <div
                      className="text-2xl font-bold"
                      style={{ fontFamily: 'var(--font-display)' }}
                    >
                      {bankAccount.currency}
                    </div>
                    <p className="text-xs text-muted-foreground mt-1">
                      {bankAccount.bankName}
                    </p>
                  </CardContent>
                </Card>
              )}
            </div>

            {/* Placeholder Content */}
            <Card>
              <CardHeader>
                <CardTitle style={{ fontFamily: 'var(--font-display)' }}>
                  Coming Soon
                </CardTitle>
                <CardDescription style={{ fontFamily: 'var(--font-body)' }}>
                  Your dashboard is under construction
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="flex flex-col items-center justify-center py-12 text-center">
                  <div className="rounded-full bg-primary/10 p-6 mb-6">
                    <LayoutDashboard className="h-12 w-12 text-primary" />
                  </div>
                  <h3
                    className="text-xl font-semibold mb-2"
                    style={{ fontFamily: 'var(--font-display)' }}
                  >
                    Dashboard Features Coming Soon
                  </h3>
                  <p
                    className="text-muted-foreground max-w-md mb-6"
                    style={{ fontFamily: 'var(--font-body)' }}
                  >
                    We're building out your complete accounting dashboard. Soon you'll be able to:
                  </p>
                  <ul
                    className="text-left space-y-2 mb-8"
                    style={{ fontFamily: 'var(--font-body)' }}
                  >
                    <li className="flex items-start gap-2">
                      <span className="text-primary mt-0.5">✓</span>
                      <span>View your financial overview and key metrics</span>
                    </li>
                    <li className="flex items-start gap-2">
                      <span className="text-primary mt-0.5">✓</span>
                      <span>Create and manage journal entries</span>
                    </li>
                    <li className="flex items-start gap-2">
                      <span className="text-primary mt-0.5">✓</span>
                      <span>Upload and categorize documents</span>
                    </li>
                    <li className="flex items-start gap-2">
                      <span className="text-primary mt-0.5">✓</span>
                      <span>Generate VAT reports and tax returns</span>
                    </li>
                    <li className="flex items-start gap-2">
                      <span className="text-primary mt-0.5">✓</span>
                      <span>Sync and reconcile bank transactions</span>
                    </li>
                  </ul>
                  <Button disabled className="gap-2">
                    <Plus className="h-4 w-4" />
                    Create Journal Entry
                  </Button>
                </div>
              </CardContent>
            </Card>
          </div>
        </main>
      </div>
    </div>
  )
}
