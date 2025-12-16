import { useState, useMemo } from 'react'
import { Head, router } from '@inertiajs/react'
import { AppLayout } from '@/components/AppLayout'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Textarea } from '@/components/ui/textarea'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import { Badge } from '@/components/ui/badge'
import {
  ArrowLeft,
  Upload,
  Building2,
  X,
  Check,
  ArrowDownRight,
  ArrowUpRight,
  AlertCircle,
  Loader2,
  PenLine,
  Trash2
} from 'lucide-react'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { BookingModal } from '@/components/BookingModal'
import { formatDate, formatAmount } from '@/utils/formatting'
import { ListFilter, FilterState } from '@/components/ListFilter'

interface Transaction {
  id: number
  bookingDate: string
  valueDate: string | null
  amount: number
  currency: string
  remittanceInformation: string | null
  counterpartyName: string | null
  counterpartyIban: string | null
  status: 'pending' | 'booked' | 'reconciled'
  config: Record<string, unknown>
  journalEntryId: number | null
  journalEntryPosted: boolean | null
}

interface Account {
  id: number
  code: string
  name: string
  accountType: string
  taxRate: number
}

interface FiscalYear {
  id: number
  year: number
  startDate: string
  endDate: string
  closed: boolean
}

interface PreviewTransaction {
  booking_date: string
  value_date: string | null
  amount: number
  remittance_information: string | null
  counterparty_name: string | null
  counterparty_iban: string | null
}

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

interface BankAccountShowProps {
  company: {
    id: number
    name: string
  }
  bankAccount: BankAccount
  transactions: Transaction[]
  recentAccounts: Account[]
  fiscalYear: FiscalYear | null
  fiscalYears: FiscalYear[]
}

type ImportStep = 'input' | 'preview' | 'success'

export default function BankAccountShow({ company, bankAccount, transactions, recentAccounts, fiscalYear, fiscalYears }: BankAccountShowProps) {
  const [showImportModal, setShowImportModal] = useState(false)
  const [importStep, setImportStep] = useState<ImportStep>('input')
  const [csvData, setCsvData] = useState('')
  const [previewData, setPreviewData] = useState<PreviewTransaction[]>([])
  const [totalCount, setTotalCount] = useState(0)
  const [importedCount, setImportedCount] = useState(0)
  const [error, setError] = useState<string | null>(null)
  const [isLoading, setIsLoading] = useState(false)

  // Booking modal state
  const [bookingModalOpen, setBookingModalOpen] = useState(false)
  const [selectedTransaction, setSelectedTransaction] = useState<Transaction | null>(null)
  const [deletingId, setDeletingId] = useState<number | null>(null)

  // Filter state
  const [filterState, setFilterState] = useState<FilterState>({
    fiscalYearId: null,
    sortOrder: 'asc',
    hideFilteredStatus: false,
    searchText: ''
  })

  // Filtered and sorted transactions
  const filteredTransactions = useMemo(() => {
    let result = [...transactions]

    // Filter by fiscal year
    if (filterState.fiscalYearId) {
      const selectedFiscalYear = fiscalYears.find(fy => fy.id === filterState.fiscalYearId)
      if (selectedFiscalYear) {
        const startDate = new Date(selectedFiscalYear.startDate)
        const endDate = new Date(selectedFiscalYear.endDate)
        result = result.filter(tx => {
          const txDate = new Date(tx.bookingDate)
          return txDate >= startDate && txDate <= endDate
        })
      }
    }

    // Filter by status (hide booked)
    if (filterState.hideFilteredStatus) {
      result = result.filter(tx => tx.status === 'pending')
    }

    // Filter by search text
    if (filterState.searchText.trim()) {
      const searchLower = filterState.searchText.toLowerCase()
      result = result.filter(tx => {
        const remittanceInfo = (tx.remittanceInformation || '').toLowerCase()
        const counterpartyName = (tx.counterpartyName || '').toLowerCase()
        return remittanceInfo.includes(searchLower) || counterpartyName.includes(searchLower)
      })
    }

    // Sort by booking date
    result.sort((a, b) => {
      const dateA = new Date(a.bookingDate).getTime()
      const dateB = new Date(b.bookingDate).getTime()
      return filterState.sortOrder === 'asc' ? dateA - dateB : dateB - dateA
    })

    return result
  }, [transactions, filterState, fiscalYears])

  const formatIban = (iban: string | null) => {
    if (!iban) return '-'
    return iban.replace(/(.{4})/g, '$1 ').trim()
  }

  const getStatusBadge = (status: Transaction['status']) => {
    switch (status) {
      case 'pending':
        return <Badge variant="outline">Pending</Badge>
      case 'booked':
        return <Badge variant="secondary">Booked</Badge>
      case 'reconciled':
        return <Badge variant="success">Reconciled</Badge>
    }
  }

  const handlePreview = async () => {
    if (!csvData.trim()) {
      setError('Please paste your transaction data')
      return
    }

    setIsLoading(true)
    setError(null)

    try {
      const response = await fetch(`/bank_accounts/${bankAccount.id}/import_preview`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '',
        },
        body: JSON.stringify({ csv_data: csvData }),
      })

      const data = await response.json()

      if (data.success) {
        setPreviewData(data.preview)
        setTotalCount(data.totalCount)
        setImportStep('preview')
      } else {
        setError(data.error || 'Failed to parse transaction data')
      }
    } catch (err) {
      setError('An error occurred while parsing the data')
    } finally {
      setIsLoading(false)
    }
  }

  const handleImport = async () => {
    setIsLoading(true)
    setError(null)

    try {
      const response = await fetch(`/bank_accounts/${bankAccount.id}/import`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '',
        },
        body: JSON.stringify({ csv_data: csvData }),
      })

      const data = await response.json()

      if (data.success) {
        setImportedCount(data.importedCount)
        setImportStep('success')
      } else {
        setError(data.error || 'Failed to import transactions')
      }
    } catch (err) {
      setError('An error occurred while importing')
    } finally {
      setIsLoading(false)
    }
  }

  const handleCloseModal = () => {
    setShowImportModal(false)
    setImportStep('input')
    setCsvData('')
    setPreviewData([])
    setTotalCount(0)
    setError(null)

    // Refresh the page if we imported transactions
    if (importStep === 'success') {
      router.reload()
    }
  }

  const handleBack = () => {
    if (importStep === 'preview') {
      setImportStep('input')
    }
  }

  const handleOpenBooking = (transaction: Transaction) => {
    setSelectedTransaction(transaction)
    setBookingModalOpen(true)
  }

  const handleBookingSuccess = () => {
    router.reload()
  }

  const handleDeleteBooking = async (journalEntryId: number) => {
    if (!confirm('Are you sure you want to delete this booking? The transaction will return to pending status.')) {
      return
    }

    setDeletingId(journalEntryId)

    try {
      const response = await fetch(`/journal_entries/${journalEntryId}`, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '',
        },
      })

      const data = await response.json()

      if (data.success) {
        router.reload()
      } else {
        alert(data.errors?.join(', ') || 'Failed to delete booking')
      }
    } catch (err) {
      alert('An error occurred while deleting the booking')
    } finally {
      setDeletingId(null)
    }
  }

  const canBook = fiscalYear && !fiscalYear.closed

  return (
    <AppLayout company={company} currentPage="bank-accounts">
      <Head title={`${bankAccount.bankName || 'Bank Account'} - ${company.name}`} />

      {/* Page Header */}
      <div className="mb-8">
        <Button
          variant="ghost"
          className="mb-4 -ml-2 gap-2"
          onClick={() => router.visit('/bank_accounts')}
        >
          <ArrowLeft className="h-4 w-4" />
          Back to Bank Accounts
        </Button>

        <div className="flex items-start justify-between">
          <div className="flex items-center gap-4">
            <div className="rounded-full bg-primary/10 p-3">
              <Building2 className="h-6 w-6 text-primary" />
            </div>
            <div>
              <h2 className="text-2xl font-semibold tracking-tight">
                {bankAccount.bankName || 'Bank Account'}
              </h2>
              <p className="text-sm text-muted-foreground">
                {formatIban(bankAccount.iban)}
              </p>
            </div>
          </div>
          <Button onClick={() => setShowImportModal(true)} className="gap-2">
            <Upload className="h-4 w-4" />
            Import Transactions
          </Button>
        </div>
      </div>

      {/* Account Info Card */}
      <div className="grid gap-4 md:grid-cols-3 mb-8">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Currency</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-semibold">{bankAccount.currency}</div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">BIC</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-semibold">{bankAccount.bic || '-'}</div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Ledger Account</CardTitle>
          </CardHeader>
          <CardContent>
            {bankAccount.ledgerAccount ? (
              <div className="text-lg font-semibold">
                {bankAccount.ledgerAccount.code} - {bankAccount.ledgerAccount.name}
              </div>
            ) : (
              <div className="text-lg text-muted-foreground">Not linked</div>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Filter Toolbar */}
      {transactions.length > 0 && (
        <ListFilter
          config={{
            showFiscalYearFilter: true,
            showSortOrder: true,
            showStatusFilter: true,
            showTextSearch: true,
            statusFilterLabel: 'Show only pending',
            statusFilterDescription: 'Hiding booked and reconciled transactions',
            searchPlaceholder: 'Search remittance info or counterparty...'
          }}
          fiscalYears={fiscalYears.map(fy => ({
            id: fy.id,
            startDate: fy.startDate,
            endDate: fy.endDate,
            label: `${fy.year}`
          }))}
          value={filterState}
          onChange={setFilterState}
        />
      )}

      {/* Transactions Card */}
      <Card>
        <CardHeader>
          <CardTitle>Transactions</CardTitle>
          <CardDescription>
            {transactions.length === 0
              ? 'No transactions yet. Import transactions to get started.'
              : `${filteredTransactions.length} of ${transactions.length} transaction${transactions.length === 1 ? '' : 's'}`
            }
          </CardDescription>
        </CardHeader>
        <CardContent>
          {filteredTransactions.length === 0 && transactions.length > 0 ? (
            <div className="flex flex-col items-center justify-center py-12">
              <div className="rounded-full bg-muted p-3 mb-4">
                <AlertCircle className="h-6 w-6 text-muted-foreground" />
              </div>
              <h3 className="font-semibold mb-1">No matching transactions</h3>
              <p className="text-sm text-muted-foreground text-center max-w-sm">
                Try adjusting your filters to see more results
              </p>
            </div>
          ) : transactions.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-12">
              <div className="rounded-full bg-muted p-3 mb-4">
                <Upload className="h-6 w-6 text-muted-foreground" />
              </div>
              <h3 className="font-semibold mb-1">No transactions</h3>
              <p className="text-sm text-muted-foreground text-center max-w-sm mb-4">
                Import your bank statement to see transactions here
              </p>
              <Button onClick={() => setShowImportModal(true)} variant="outline" className="gap-2">
                <Upload className="h-4 w-4" />
                Import Transactions
              </Button>
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="w-[100px]">Date</TableHead>
                  <TableHead>Description</TableHead>
                  <TableHead>Counterparty</TableHead>
                  <TableHead className="text-right">Amount</TableHead>
                  <TableHead className="w-[100px]">Status</TableHead>
                  <TableHead className="w-[100px]">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filteredTransactions.map((tx) => (
                  <TableRow key={tx.id}>
                    <TableCell className="font-mono text-sm">
                      {formatDate(tx.bookingDate)}
                    </TableCell>
                    <TableCell>
                      <div className="max-w-[300px]">
                        {tx.remittanceInformation || '-'}
                      </div>
                    </TableCell>
                    <TableCell>
                      <div>
                        {tx.counterpartyName || '-'}
                      </div>
                      {tx.counterpartyIban && (
                        <div className="text-xs text-muted-foreground font-mono">
                          {tx.counterpartyIban}
                        </div>
                      )}
                    </TableCell>
                    <TableCell className="text-right">
                      <div className={`flex items-center justify-end gap-1 font-semibold ${tx.amount >= 0 ? 'text-green-600' : 'text-red-600'
                        }`}>
                        {tx.amount >= 0 ? (
                          <ArrowDownRight className="h-4 w-4" />
                        ) : (
                          <ArrowUpRight className="h-4 w-4" />
                        )}
                        {formatAmount(tx.amount, tx.currency)}
                      </div>
                    </TableCell>
                    <TableCell>
                      {getStatusBadge(tx.status)}
                    </TableCell>
                    <TableCell>
                      {tx.status === 'pending' && canBook && (
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => handleOpenBooking(tx)}
                          title="Book transaction"
                        >
                          <PenLine className="h-4 w-4" />
                        </Button>
                      )}
                      {tx.status === 'booked' && tx.journalEntryId && !tx.journalEntryPosted && (
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => handleDeleteBooking(tx.journalEntryId!)}
                          disabled={deletingId === tx.journalEntryId}
                          title="Delete booking"
                        >
                          {deletingId === tx.journalEntryId ? (
                            <Loader2 className="h-4 w-4 animate-spin" />
                          ) : (
                            <Trash2 className="h-4 w-4 text-destructive" />
                          )}
                        </Button>
                      )}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      {/* Import Modal */}
      {showImportModal && (
        <div className="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4">
          <Card className="w-full max-w-2xl max-h-[90vh] overflow-auto bg-background dark:bg-gray-900">
            <CardHeader className="flex flex-row items-center justify-between">
              <div>
                <CardTitle>
                  {importStep === 'input' && 'Import Transactions'}
                  {importStep === 'preview' && 'Preview Import'}
                  {importStep === 'success' && 'Import Complete'}
                </CardTitle>
                <CardDescription>
                  {importStep === 'input' && 'Paste your bank statement data (CSV, tab or semicolon separated)'}
                  {importStep === 'preview' && `Showing ${previewData.length} of ${totalCount} transactions`}
                  {importStep === 'success' && `Successfully imported ${importedCount} transactions`}
                </CardDescription>
              </div>
              <Button variant="ghost" size="icon" onClick={handleCloseModal}>
                <X className="h-4 w-4" />
              </Button>
            </CardHeader>
            <CardContent className="space-y-4">
              {error && (
                <Alert variant="destructive">
                  <AlertCircle className="h-4 w-4" />
                  <AlertDescription>{error}</AlertDescription>
                </Alert>
              )}

              {importStep === 'input' && (
                <>
                  <div className="space-y-2">
                    <Textarea
                      placeholder={`Paste your transaction data here...

Example formats supported:
- Tab-separated (from Excel)
- Semicolon-separated (German CSV)
- Comma-separated

German date format (DD.MM.YYYY) and currency format (1.234,56 €) are supported.`}
                      className="min-h-[300px] font-mono text-sm"
                      value={csvData}
                      onChange={(e) => setCsvData(e.target.value)}
                    />
                    <p className="text-xs text-muted-foreground">
                      The system will try to auto-detect columns. Common headers: Buchungstag, Betrag, Verwendungszweck, Auftraggeber/Empfänger
                    </p>
                  </div>
                  <div className="flex justify-end gap-2">
                    <Button variant="outline" onClick={handleCloseModal}>
                      Cancel
                    </Button>
                    <Button onClick={handlePreview} disabled={isLoading}>
                      {isLoading ? (
                        <>
                          <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                          Parsing...
                        </>
                      ) : (
                        'Preview Import'
                      )}
                    </Button>
                  </div>
                </>
              )}

              {importStep === 'preview' && (
                <>
                  <div className="border rounded-lg overflow-hidden">
                    <Table>
                      <TableHeader>
                        <TableRow>
                          <TableHead>Date</TableHead>
                          <TableHead className="text-right">Amount</TableHead>
                          <TableHead>Description</TableHead>
                          <TableHead>Counterparty</TableHead>
                        </TableRow>
                      </TableHeader>
                      <TableBody>
                        {previewData.map((tx, index) => (
                          <TableRow key={index}>
                            <TableCell className="font-mono text-sm">
                              {tx.booking_date ? formatDate(tx.booking_date) : '-'}
                            </TableCell>
                            <TableCell className={`text-right font-semibold ${tx.amount >= 0 ? 'text-green-600' : 'text-red-600'
                              }`}>
                              {formatAmount(tx.amount, bankAccount.currency)}
                            </TableCell>
                            <TableCell className="max-w-[200px]">
                              {tx.remittance_information || '-'}
                            </TableCell>
                            <TableCell>
                              {tx.counterparty_name || '-'}
                            </TableCell>
                          </TableRow>
                        ))}
                      </TableBody>
                    </Table>
                  </div>
                  {totalCount > previewData.length && (
                    <p className="text-sm text-muted-foreground text-center">
                      ... and {totalCount - previewData.length} more transactions
                    </p>
                  )}
                  <div className="flex justify-between">
                    <Button variant="outline" onClick={handleBack}>
                      Back
                    </Button>
                    <div className="flex gap-2">
                      <Button variant="outline" onClick={handleCloseModal}>
                        Cancel
                      </Button>
                      <Button onClick={handleImport} disabled={isLoading}>
                        {isLoading ? (
                          <>
                            <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                            Importing...
                          </>
                        ) : (
                          `Import ${totalCount} Transactions`
                        )}
                      </Button>
                    </div>
                  </div>
                </>
              )}

              {importStep === 'success' && (
                <>
                  <div className="flex flex-col items-center justify-center py-8">
                    <div className="rounded-full bg-green-500/10 p-3 mb-4">
                      <Check className="h-8 w-8 text-green-600" />
                    </div>
                    <h3 className="text-lg font-semibold mb-1">Import Successful</h3>
                    <p className="text-sm text-muted-foreground text-center">
                      {importedCount} transaction{importedCount === 1 ? ' has' : 's have'} been imported
                    </p>
                  </div>
                  <div className="flex justify-end">
                    <Button onClick={handleCloseModal}>
                      Done
                    </Button>
                  </div>
                </>
              )}
            </CardContent>
          </Card>
        </div>
      )}

      {/* Booking Modal */}
      <BookingModal
        open={bookingModalOpen}
        onOpenChange={setBookingModalOpen}
        transaction={selectedTransaction}
        recentAccounts={recentAccounts}
        onSuccess={handleBookingSuccess}
      />
    </AppLayout>
  )
}
