import { Head, router } from '@inertiajs/react'
import { AppLayout } from '@/components/AppLayout'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import { Badge } from '@/components/ui/badge'
import { Wallet, ChevronRight, Building2 } from 'lucide-react'

interface BankAccount {
  id: number
  bankName: string | null
  iban: string | null
  bic: string | null
  currency: string
  ledgerAccount: {
    id: number
    code: string
    name: string
  } | null
  transactionCount: number
}

interface BankAccountsIndexProps {
  company: {
    id: number
    name: string
  }
  bankAccounts: BankAccount[]
}

export default function BankAccountsIndex({ company, bankAccounts }: BankAccountsIndexProps) {
  const formatIban = (iban: string | null) => {
    if (!iban) return '-'
    // Format IBAN in groups of 4
    return iban.replace(/(.{4})/g, '$1 ').trim()
  }

  return (
    <AppLayout company={company} currentPage="bank-accounts">
      <Head title={`Bank Accounts - ${company.name}`} />

      {/* Page Header */}
      <div className="mb-8">
        <h2 className="text-2xl font-semibold tracking-tight mb-1">
          Bank Accounts
        </h2>
        <p className="text-sm text-muted-foreground">
          Manage your company's bank accounts and transactions
        </p>
      </div>

      {bankAccounts.length === 0 ? (
        <Card>
          <CardContent className="flex flex-col items-center justify-center py-12">
            <div className="rounded-full bg-primary/10 p-3 mb-4">
              <Wallet className="h-6 w-6 text-primary" />
            </div>
            <h3 className="font-semibold mb-1">No bank accounts yet</h3>
            <p className="text-sm text-muted-foreground text-center max-w-sm">
              Add a bank account during onboarding to start tracking your transactions.
            </p>
          </CardContent>
        </Card>
      ) : (
        <Card>
          <CardHeader>
            <CardTitle>Your Bank Accounts</CardTitle>
            <CardDescription>
              Click on an account to view transactions and import statements
            </CardDescription>
          </CardHeader>
          <CardContent>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Bank</TableHead>
                  <TableHead>IBAN</TableHead>
                  <TableHead>Ledger Account</TableHead>
                  <TableHead className="text-right">Transactions</TableHead>
                  <TableHead className="w-[50px]"></TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {bankAccounts.map((account) => (
                  <TableRow
                    key={account.id}
                    className="cursor-pointer"
                    onClick={() => router.visit(`/bank_accounts/${account.id}`)}
                  >
                    <TableCell>
                      <div className="flex items-center gap-3">
                        <div className="rounded-full bg-primary/10 p-2">
                          <Building2 className="h-4 w-4 text-primary" />
                        </div>
                        <div>
                          <div className="font-medium">
                            {account.bankName || 'Unknown Bank'}
                          </div>
                          {account.bic && (
                            <div className="text-xs text-muted-foreground">
                              BIC: {account.bic}
                            </div>
                          )}
                        </div>
                      </div>
                    </TableCell>
                    <TableCell>
                      <code className="text-sm bg-muted px-2 py-1 rounded">
                        {formatIban(account.iban)}
                      </code>
                    </TableCell>
                    <TableCell>
                      {account.ledgerAccount ? (
                        <Badge variant="secondary">
                          {account.ledgerAccount.code} - {account.ledgerAccount.name}
                        </Badge>
                      ) : (
                        <span className="text-muted-foreground">Not linked</span>
                      )}
                    </TableCell>
                    <TableCell className="text-right">
                      <Badge variant={account.transactionCount > 0 ? 'default' : 'outline'}>
                        {account.transactionCount}
                      </Badge>
                    </TableCell>
                    <TableCell>
                      <ChevronRight className="h-4 w-4 text-muted-foreground" />
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </Card>
      )}
    </AppLayout>
  )
}
