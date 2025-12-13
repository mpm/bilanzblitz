import { router } from '@inertiajs/react'
import { Fragment, useState } from 'react'
import { AppLayout } from '@/components/AppLayout'
import { Button } from '@/components/ui/button'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import { Badge } from '@/components/ui/badge'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { PenLine, Trash2, FileText, Plus } from 'lucide-react'
import { JournalEntryModal } from '@/components/JournalEntryModal'

interface FiscalYear {
  id: number
  year: number
  startDate: string
  endDate: string
  closed: boolean
}

interface LineItem {
  id: number
  accountCode: string
  accountName: string
  amount: number
  direction: 'debit' | 'credit'
  bankTransactionId: number | null
}

interface JournalEntry {
  id: number
  bookingDate: string
  description: string
  postedAt: string | null
  fiscalYearId: number
  fiscalYearClosed: boolean
  lineItems: LineItem[]
}

interface Account {
  id: number
  code: string
  name: string
  accountType: string
  taxRate: number
}

interface JournalEntriesIndexProps {
  company: { id: number; name: string }
  fiscalYears: FiscalYear[]
  selectedFiscalYearId: number | null
  journalEntries: JournalEntry[]
  recentAccounts: Account[]
}

export default function JournalEntriesIndex({
  company,
  fiscalYears,
  selectedFiscalYearId,
  journalEntries,
  recentAccounts,
}: JournalEntriesIndexProps) {
  const [modalOpen, setModalOpen] = useState(false)
  const [editEntryId, setEditEntryId] = useState<number | null>(null)

  const handleFiscalYearChange = (value: string) => {
    if (value === 'all') {
      router.visit('/journal_entries?fiscal_year_id=all')
    } else {
      router.visit(`/journal_entries?fiscal_year_id=${value}`)
    }
  }

  const handleNewEntry = () => {
    setEditEntryId(null)
    setModalOpen(true)
  }

  const handleEdit = (entryId: number) => {
    setEditEntryId(entryId)
    setModalOpen(true)
  }

  const handleDelete = async (entryId: number) => {
    if (!confirm('Are you sure you want to delete this journal entry?')) {
      return
    }

    const csrfToken = document
      .querySelector('meta[name="csrf-token"]')
      ?.getAttribute('content')

    try {
      const response = await fetch(`/journal_entries/${entryId}`, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken || '',
        },
      })

      const data = await response.json()

      if (data.success) {
        router.reload()
      } else {
        alert(`Error: ${data.errors.join(', ')}`)
      }
    } catch (error) {
      console.error('Delete failed:', error)
      alert('Failed to delete journal entry. Please try again.')
    }
  }

  const handleModalSuccess = () => {
    setModalOpen(false)
    setEditEntryId(null)
  }

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('de-DE', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    })
  }

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('de-DE', {
      style: 'currency',
      currency: 'EUR',
    }).format(amount)
  }

  const calculateDebits = (entry: JournalEntry) => {
    return entry.lineItems
      .filter((li) => li.direction === 'debit')
      .reduce((sum, li) => sum + li.amount, 0)
  }

  const calculateCredits = (entry: JournalEntry) => {
    return entry.lineItems
      .filter((li) => li.direction === 'credit')
      .reduce((sum, li) => sum + li.amount, 0)
  }

  const hasOpenFiscalYear = fiscalYears.some((fy) => !fy.closed)

  const editEntry = editEntryId
    ? journalEntries.find((e) => e.id === editEntryId)
    : null

  return (
    <AppLayout company={company} currentPage="journal-entries">
      <div className="space-y-6">
        {/* Page Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold tracking-tight">Journal Entries</h1>
            <p className="text-muted-foreground mt-1">
              View and manage all journal entries
            </p>
          </div>
          {hasOpenFiscalYear && (
            <Button onClick={handleNewEntry}>
              <Plus className="h-4 w-4 mr-2" />
              New Journal Entry
            </Button>
          )}
        </div>

        {/* Fiscal Year Filter */}
        <div className="flex items-center gap-4">
          <label className="text-sm font-medium">Fiscal Year:</label>
          {fiscalYears.length > 0 ? (
            <Select
              value={selectedFiscalYearId?.toString() || 'all'}
              onValueChange={handleFiscalYearChange}
            >
              <SelectTrigger className="w-[250px]">
                <SelectValue placeholder="Select fiscal year" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Fiscal Years</SelectItem>
                {fiscalYears.map((fy) => (
                  <SelectItem key={fy.id} value={fy.id.toString()}>
                    {fy.year} {fy.closed && '(Closed)'}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          ) : (
            <span className="text-sm text-muted-foreground">
              No fiscal years found
            </span>
          )}
        </div>

        {/* Warning if no open fiscal years */}
        {!hasOpenFiscalYear && fiscalYears.length > 0 && (
          <div className="rounded-lg border border-yellow-200 bg-yellow-50 p-4">
            <p className="text-sm text-yellow-800">
              All fiscal years are closed. You cannot create or edit journal entries.
            </p>
          </div>
        )}

        {/* Journal Entries Table */}
        {journalEntries.length === 0 ? (
          <Card>
            <CardContent className="flex flex-col items-center justify-center py-12">
              <FileText className="h-12 w-12 text-muted-foreground mb-4" />
              <h3 className="font-semibold mb-2">No journal entries found</h3>
              <p className="text-sm text-muted-foreground mb-4">
                {selectedFiscalYearId
                  ? 'No entries for this fiscal year'
                  : 'Create your first journal entry to get started'}
              </p>
              {hasOpenFiscalYear && (
                <Button onClick={handleNewEntry}>Create Entry</Button>
              )}
            </CardContent>
          </Card>
        ) : (
          <Card>
            <CardHeader>
              <CardTitle>Journal Entries</CardTitle>
            </CardHeader>
            <CardContent>
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead className="w-[120px]">Date</TableHead>
                    <TableHead className="w-[150px]">Account Code</TableHead>
                    <TableHead>Account Name</TableHead>
                    <TableHead>Description</TableHead>
                    <TableHead className="text-right w-[120px]">Debit</TableHead>
                    <TableHead className="text-right w-[120px]">Credit</TableHead>
                    <TableHead className="w-[120px]">Actions</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {journalEntries.map((entry, entryIdx) => (
                    <Fragment key={entry.id}>
                      {/* Entry header row */}
                      <TableRow
                        className={`border-t-2 ${
                          entryIdx % 2 === 0 ? 'bg-muted/30' : 'bg-background'
                        }`}
                      >
                        <TableCell className="font-medium" colSpan={2}>
                          {formatDate(entry.bookingDate)}
                        </TableCell>
                        <TableCell colSpan={2}>{entry.description}</TableCell>
                        <TableCell colSpan={2}></TableCell>
                        <TableCell>
                          <div className="flex gap-2">
                            {!entry.postedAt && !entry.fiscalYearClosed && (
                              <>
                                <Button
                                  size="sm"
                                  variant="ghost"
                                  onClick={() => handleEdit(entry.id)}
                                  title="Edit journal entry"
                                >
                                  <PenLine className="h-4 w-4" />
                                </Button>
                                <Button
                                  size="sm"
                                  variant="ghost"
                                  onClick={() => handleDelete(entry.id)}
                                  title="Delete journal entry"
                                >
                                  <Trash2 className="h-4 w-4" />
                                </Button>
                              </>
                            )}
                            {entry.postedAt && <Badge variant="secondary">Posted</Badge>}
                            {entry.fiscalYearClosed && !entry.postedAt && (
                              <Badge variant="secondary">Closed FY</Badge>
                            )}
                          </div>
                        </TableCell>
                      </TableRow>

                      {/* Line item rows */}
                      {entry.lineItems.map((lineItem) => (
                        <TableRow
                          key={lineItem.id}
                          className={
                            entryIdx % 2 === 0 ? 'bg-muted/30' : 'bg-background'
                          }
                        >
                          <TableCell></TableCell>
                          <TableCell className="pl-8 font-mono text-sm">
                            {lineItem.accountCode}
                          </TableCell>
                          <TableCell>{lineItem.accountName}</TableCell>
                          <TableCell className="text-sm text-muted-foreground">
                            {lineItem.bankTransactionId && '(Bank transaction)'}
                          </TableCell>
                          <TableCell className="text-right font-mono text-red-600">
                            {lineItem.direction === 'debit' &&
                              formatCurrency(lineItem.amount)}
                          </TableCell>
                          <TableCell className="text-right font-mono text-green-600">
                            {lineItem.direction === 'credit' &&
                              formatCurrency(lineItem.amount)}
                          </TableCell>
                          <TableCell></TableCell>
                        </TableRow>
                      ))}

                      {/* Subtotal row */}
                      <TableRow
                        className={`border-b ${
                          entryIdx % 2 === 0 ? 'bg-muted/30' : 'bg-background'
                        }`}
                      >
                        <TableCell colSpan={4} className="text-right text-sm font-medium">
                          Subtotal:
                        </TableCell>
                        <TableCell className="text-right font-mono text-sm">
                          {formatCurrency(calculateDebits(entry))}
                        </TableCell>
                        <TableCell className="text-right font-mono text-sm">
                          {formatCurrency(calculateCredits(entry))}
                        </TableCell>
                        <TableCell></TableCell>
                      </TableRow>
                    </Fragment>
                  ))}
                </TableBody>
              </Table>
            </CardContent>
          </Card>
        )}
      </div>

      {/* Journal Entry Modal */}
      <JournalEntryModal
        open={modalOpen}
        onOpenChange={setModalOpen}
        journalEntry={editEntry || null}
        recentAccounts={recentAccounts}
        fiscalYears={fiscalYears}
        onSuccess={handleModalSuccess}
      />
    </AppLayout>
  )
}
