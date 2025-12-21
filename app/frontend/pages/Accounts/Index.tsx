import { Head, router } from '@inertiajs/react'
import { useState, useMemo } from 'react'
import { AppLayout } from '@/components/AppLayout'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { Search } from 'lucide-react'

interface Account {
  id: number
  code: string
  name: string
  accountType: string
}

interface AccountsIndexProps {
  company: { id: number; name: string }
  accounts: Account[]
}

export default function AccountsIndex({ company, accounts }: AccountsIndexProps) {
  const [searchText, setSearchText] = useState('')

  // Filter accounts by search text
  const filteredAccounts = useMemo(() => {
    if (!searchText.trim()) return accounts

    const searchLower = searchText.toLowerCase()
    return accounts.filter((account) => {
      return (
        account.code.toLowerCase().includes(searchLower) ||
        account.name.toLowerCase().includes(searchLower)
      )
    })
  }, [accounts, searchText])

  const handleAccountClick = (accountId: number) => {
    router.visit(`/accounts/${accountId}`)
  }

  const getAccountTypeBadge = (accountType: string) => {
    const variants: Record<string, { label: string; variant: 'default' | 'secondary' | 'outline' }> = {
      asset: { label: 'Asset', variant: 'default' },
      liability: { label: 'Liability', variant: 'secondary' },
      equity: { label: 'Equity', variant: 'outline' },
      expense: { label: 'Expense', variant: 'secondary' },
      revenue: { label: 'Revenue', variant: 'default' },
    }

    const config = variants[accountType] || { label: accountType, variant: 'outline' }
    return <Badge variant={config.variant}>{config.label}</Badge>
  }

  return (
    <AppLayout company={company} currentPage="accounts">
      <Head title="Chart of Accounts" />

      <div className="space-y-6">
        {/* Header */}
        <div>
          <h1 className="text-3xl font-bold">Chart of Accounts</h1>
          <p className="text-muted-foreground">
            View all accounts for {company.name}
          </p>
        </div>

        {/* Search */}
        <div className="relative">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            placeholder="Search by account code or name..."
            value={searchText}
            onChange={(e) => setSearchText(e.target.value)}
            className="pl-10"
          />
        </div>

        {/* Accounts Table */}
        <Card>
          <CardHeader>
            <CardTitle>
              {filteredAccounts.length} Account{filteredAccounts.length !== 1 ? 's' : ''}
            </CardTitle>
          </CardHeader>
          <CardContent>
            {filteredAccounts.length === 0 ? (
              <div className="text-center py-8 text-muted-foreground">
                No accounts found matching your search.
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead className="border-b">
                    <tr>
                      <th className="text-left py-3 px-4 font-semibold text-sm">Code</th>
                      <th className="text-left py-3 px-4 font-semibold text-sm">Name</th>
                      <th className="text-left py-3 px-4 font-semibold text-sm">Type</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredAccounts.map((account) => (
                      <tr
                        key={account.id}
                        onClick={() => handleAccountClick(account.id)}
                        className="border-b hover:bg-accent/50 cursor-pointer transition-colors"
                      >
                        <td className="py-3 px-4">
                          <span className="font-mono text-sm font-medium">
                            {account.code}
                          </span>
                        </td>
                        <td className="py-3 px-4 text-sm">{account.name}</td>
                        <td className="py-3 px-4">
                          {getAccountTypeBadge(account.accountType)}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </AppLayout>
  )
}
