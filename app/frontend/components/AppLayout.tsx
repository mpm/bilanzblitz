import { router } from '@inertiajs/react'
import { Button } from '@/components/ui/button'
import {
  LayoutDashboard,
  Building2,
  Wallet,
  FileText,
  BarChart3,
  Settings,
  LogOut,
} from 'lucide-react'

interface AppLayoutProps {
  company: {
    id: number
    name: string
  }
  currentPage: 'dashboard' | 'bank-accounts' | 'journal-entries' | 'documents' | 'reports' | 'balance-sheet'
  children: React.ReactNode
}

export function AppLayout({ company, currentPage, children }: AppLayoutProps) {
  const handleLogout = () => {
    router.delete('/users/sign_out')
  }

  const navItems = [
    { key: 'dashboard', label: 'Dashboard', icon: LayoutDashboard, href: '/dashboard', enabled: true },
    { key: 'journal-entries', label: 'Journal Entries', icon: FileText, href: '#', enabled: false },
    { key: 'bank-accounts', label: 'Bank Accounts', icon: Wallet, href: '/bank_accounts', enabled: true },
    { key: 'documents', label: 'Documents', icon: FileText, href: '#', enabled: false },
    { key: 'reports', label: 'Reports', icon: BarChart3, href: '/reports/balance_sheet', enabled: true },
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
