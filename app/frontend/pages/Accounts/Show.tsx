import { Head, router } from '@inertiajs/react'
import { useState, useMemo, useEffect } from 'react'
import { AppLayout } from '@/components/AppLayout'
import { Card, CardContent } from '@/components/ui/card'
import { ListFilter, FilterState } from '@/components/ListFilter'
import { JournalEntryModal } from '@/components/JournalEntryModal'
import { AccountLedgerTable } from '@/components/accounts/AccountLedgerTable'
import { AccountLedgerData, FiscalYear } from '@/types/accounting'
import type { JournalEntry } from '@/types/journal-entries'

interface Account {
  id: number
  code: string
  name: string
  accountType: string
}

interface AccountShowProps {
  company: { id: number; name: string }
  fiscalYears: FiscalYear[]
  selectedFiscalYearId: number | null
  account: Account
  ledgerData: AccountLedgerData
}

export default function AccountShow({
  company,
  fiscalYears,
  selectedFiscalYearId,
  account,
  ledgerData,
}: AccountShowProps) {
  const [filterState, setFilterState] = useState<FilterState>({
    fiscalYearId: selectedFiscalYearId,
    sortOrder: 'asc',
    hideFilteredStatus: false,
    searchText: '',
  })

  const [modalOpen, setModalOpen] = useState(false)
  const [selectedEntryId, setSelectedEntryId] = useState<number | null>(null)

  // Sync filter state with prop changes (e.g., when user navigates back)
  useEffect(() => {
    setFilterState((prev) => ({
      ...prev,
      fiscalYearId: selectedFiscalYearId,
    }))
  }, [selectedFiscalYearId])

  // Handle fiscal year change via ListFilter
  useEffect(() => {
    if (filterState.fiscalYearId !== selectedFiscalYearId) {
      const url =
        filterState.fiscalYearId
          ? `/accounts/${account.id}?fiscal_year_id=${filterState.fiscalYearId}`
          : `/accounts/${account.id}`
      router.visit(url)
    }
  }, [filterState.fiscalYearId, selectedFiscalYearId, account.id])

  // Filter line items by search text (client-side)
  const filteredLedgerData = useMemo(() => {
    if (!filterState.searchText.trim()) return ledgerData

    const searchLower = filterState.searchText.toLowerCase()
    const filteredGroups = ledgerData.lineItemGroups
      .map((group) => ({
        ...group,
        lineItems: group.lineItems.filter((li) => {
          const description = (li.description || group.description || '').toLowerCase()
          const accountCode = li.accountCode.toLowerCase()
          const accountName = li.accountName.toLowerCase()
          return (
            description.includes(searchLower) ||
            accountCode.includes(searchLower) ||
            accountName.includes(searchLower)
          )
        }),
      }))
      .filter((group) => group.lineItems.length > 0)

    return { ...ledgerData, lineItemGroups: filteredGroups }
  }, [ledgerData, filterState.searchText])

  const handleLineItemClick = (journalEntryId: number) => {
    setSelectedEntryId(journalEntryId)
    setModalOpen(true)
  }

  const handleModalSuccess = () => {
    setModalOpen(false)
    router.reload() // Refresh ledger data after edit
  }

  // Construct journal entry object from ledger data for editing
  const selectedEntry = useMemo<JournalEntry | null>(() => {
    if (!selectedEntryId) return null

    const group = ledgerData.lineItemGroups.find((g) => g.journalEntryId === selectedEntryId)
    if (!group) return null

    return {
      id: selectedEntryId,
      bookingDate: group.bookingDate,
      description: group.description,
      postedAt: group.postedAt,
      fiscalYearId: ledgerData.fiscalYear?.id || 0,
      fiscalYearYear: ledgerData.fiscalYear?.year || 0,
      fiscalYearClosed: group.fiscalYearClosed,
      entryType: 'normal',
      sequence: null,
      lineItems: group.lineItems.map((li) => ({
        id: li.id,
        accountCode: li.accountCode,
        accountName: li.accountName,
        amount: li.amount,
        direction: li.direction,
        bankTransactionId: null,
        description: li.description,
      })),
    }
  }, [selectedEntryId, ledgerData])

  return (
    <AppLayout company={company} currentPage="accounts">
      <Head title={`${account.code} ${account.name} - Ledger`} />

      <div className="space-y-6">
        {/* Header */}
        <div>
          <h1 className="text-3xl font-bold">
            {account.code} - {account.name}
          </h1>
          <p className="text-muted-foreground">Account Type: {account.accountType}</p>
        </div>

        {/* Filter */}
        <ListFilter
          config={{
            showFiscalYearFilter: true,
            showTextSearch: true,
            showSortOrder: false,
            showStatusFilter: false,
            searchPlaceholder: 'Search descriptions, accounts...',
          }}
          fiscalYears={fiscalYears.map((fy) => ({
            id: fy.id,
            startDate: fy.startDate,
            endDate: fy.endDate,
            label: `${fy.year}`,
          }))}
          value={filterState}
          onChange={setFilterState}
        />

        {/* Ledger Table */}
        <Card>
          <CardContent className="p-0">
            <AccountLedgerTable
              ledgerData={filteredLedgerData}
              onLineItemClick={handleLineItemClick}
              compact={false}
            />
          </CardContent>
        </Card>
      </div>

      {/* Edit Modal */}
      <JournalEntryModal
        open={modalOpen}
        onOpenChange={setModalOpen}
        journalEntry={selectedEntry}
        recentAccounts={[]} // Could load from context or server if needed
        fiscalYears={fiscalYears}
        onSuccess={handleModalSuccess}
      />
    </AppLayout>
  )
}
