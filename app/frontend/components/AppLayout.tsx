import { router, usePage } from '@inertiajs/react'
import { useEffect, useState } from 'react'
import { Button } from '@/components/ui/button'
import { Switch } from '@/components/ui/switch'
import { Label } from '@/components/ui/label'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import {
  LayoutDashboard,
  Building2,
  Wallet,
  FileText,
  BarChart3,
  Calendar,
  FileCheck,
  Settings,
  LogOut,
} from 'lucide-react'

interface FiscalYear {
  id: number
  year: number
  closed: boolean
}

interface AppLayoutProps {
  company: {
    id: number
    name: string
  }
  currentPage: 'dashboard' | 'bank-accounts' | 'journal-entries' | 'documents' | 'reports' | 'balance-sheet' | 'fiscal-years' | 'tax-reports'
  children: React.ReactNode
}

export function AppLayout({ company, currentPage, children }: AppLayoutProps) {
  const { props } = usePage()
  const userConfig = (props.userConfig || {}) as {
    ui?: { theme?: string }
    fiscal_years?: Record<string, number>
  }
  const fiscalYears = (props.fiscalYears || []) as FiscalYear[]

  const [theme, setTheme] = useState<'light' | 'dark'>(
    (userConfig.ui?.theme === 'dark' ? 'dark' : 'light') as 'light' | 'dark'
  )

  // Get the preferred fiscal year for this company
  const preferredYear = userConfig.fiscal_years?.[company.id.toString()]
  const [selectedYear, setSelectedYear] = useState<number | null>(
    preferredYear || (fiscalYears.length > 0 ? fiscalYears[0].year : null)
  )

  // Debug: Log the user config
  useEffect(() => {
    console.log('User config:', userConfig)
    console.log('Theme:', userConfig.ui?.theme)
  }, [])

  // Apply dark mode class to HTML element on mount and when theme changes
  useEffect(() => {
    console.log('Applying theme:', theme)
    if (theme === 'dark') {
      document.documentElement.classList.add('dark')
    } else {
      document.documentElement.classList.remove('dark')
    }
  }, [theme])

  const handleDarkModeToggle = async (checked: boolean) => {
    const newTheme = checked ? 'dark' : 'light'
    setTheme(newTheme)

    // Update user preference in backend
    try {
      await fetch('/user_preferences', {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content || '',
        },
        body: JSON.stringify({ theme: newTheme }),
      })
    } catch (error) {
      console.error('Failed to update theme preference:', error)
    }
  }

  const handleFiscalYearChange = async (yearString: string) => {
    const year = parseInt(yearString)
    setSelectedYear(year)

    // Update user preference in backend
    try {
      await fetch('/user_preferences', {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content || '',
        },
        body: JSON.stringify({
          fiscal_year: year,
          company_id: company.id,
        }),
      })

      // Reload the page to apply the new fiscal year filter
      router.reload()
    } catch (error) {
      console.error('Failed to update fiscal year preference:', error)
    }
  }

  const handleLogout = () => {
    router.delete('/users/sign_out')
  }

  const navItems = [
    { key: 'dashboard', label: 'Dashboard', icon: LayoutDashboard, href: '/dashboard', enabled: true },
    { key: 'journal-entries', label: 'Journal Entries', icon: FileText, href: '/journal_entries', enabled: true },
    { key: 'bank-accounts', label: 'Bank Accounts', icon: Wallet, href: '/bank_accounts', enabled: true },
    { key: 'documents', label: 'Documents', icon: FileText, href: '/documents', enabled: true },
    { key: 'reports', label: 'Reports', icon: BarChart3, href: '/reports/balance_sheet', enabled: true },
    { key: 'fiscal-years', label: 'Fiscal Years', icon: Calendar, href: '/fiscal_years', enabled: true },
    { key: 'tax-reports', label: 'Tax Reports', icon: FileCheck, href: '/tax_reports', enabled: true },
  ]

  return (
    <div className="min-h-screen bg-background">
      {/* Top Navigation - Stripe style */}
      <header className="sticky top-0 z-50 w-full border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
        <div className="flex h-14 items-center px-4 sm:px-6">
          <div className="flex items-center gap-4 flex-1">
            <h1
              className="text-lg font-semibold tracking-tight cursor-pointer"
              onClick={() => router.visit('/dashboard')}
            >
              Bilanz<span className="text-primary">Blitz</span>
            </h1>
            <div className="h-4 w-px bg-border" />
            <div className="flex items-center gap-2 text-sm text-muted-foreground">
              <Building2 className="h-4 w-4" />
              <span className="font-medium text-foreground">{company.name}</span>
            </div>

            {/* Fiscal Year Selector */}
            {fiscalYears.length > 0 && (
              <>
                <div className="h-4 w-px bg-border" />
                <div className="flex items-center gap-2">
                  <Calendar className="h-4 w-4 text-muted-foreground" />
                  <Select
                    value={selectedYear?.toString() || ''}
                    onValueChange={handleFiscalYearChange}
                  >
                    <SelectTrigger className="h-8 w-[140px] text-sm">
                      <SelectValue placeholder="Select year" />
                    </SelectTrigger>
                    <SelectContent>
                      {fiscalYears.map((fy) => (
                        <SelectItem key={fy.id} value={fy.year.toString()}>
                          {fy.year} {fy.closed && '(Closed)'}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </>
            )}
          </div>

          <div className="flex items-center gap-2">
            <Popover>
              <PopoverTrigger asChild>
                <Button variant="ghost" size="icon" className="h-8 w-8">
                  <Settings className="h-4 w-4" />
                </Button>
              </PopoverTrigger>
              <PopoverContent className="w-64" align="end">
                <div className="space-y-4">
                  <h4 className="font-medium text-sm">Settings</h4>
                  <div className="flex items-center justify-between">
                    <Label htmlFor="dark-mode" className="text-sm font-normal">
                      Dark Mode
                    </Label>
                    <Switch
                      id="dark-mode"
                      checked={theme === 'dark'}
                      onCheckedChange={handleDarkModeToggle}
                    />
                  </div>
                </div>
              </PopoverContent>
            </Popover>
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
            {navItems.map((item) => {
              const Icon = item.icon
              const isActive = currentPage === item.key
              return (
                <Button
                  key={item.key}
                  variant={isActive ? 'secondary' : 'ghost'}
                  className={`w-full justify-start gap-3 font-normal ${
                    !isActive && item.enabled ? 'text-muted-foreground' : ''
                  }`}
                  disabled={!item.enabled}
                  onClick={() => item.enabled && router.visit(item.href)}
                >
                  <Icon className="h-4 w-4" />
                  {item.label}
                </Button>
              )
            })}
          </nav>
        </aside>

        {/* Main Content */}
        <main className="flex-1">
          <div className="mx-auto max-w-7xl p-4 sm:p-6 lg:p-8">
            {children}
          </div>
        </main>
      </div>
    </div>
  )
}
