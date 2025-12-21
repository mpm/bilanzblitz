import { useState, useMemo } from 'react'
import { router } from '@inertiajs/react'
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from '@/components/ui/popover'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { JournalEntryModal } from '@/components/JournalEntryModal'
import { AccountLedgerTable } from '@/components/accounts/AccountLedgerTable'
import { AccountLedgerData } from '@/types/accounting'
import type { JournalEntry } from '@/types/journal-entries'
import { AlertCircle, Loader2 } from 'lucide-react'

interface AccountLedgerPopoverProps {
  accountId: number
  fiscalYearId: number
  children: React.ReactNode
}

export function AccountLedgerPopover({
  accountId,
  fiscalYearId,
  children,
}: AccountLedgerPopoverProps) {
  const [isOpen, setIsOpen] = useState(false)
  const [ledgerData, setLedgerData] = useState<AccountLedgerData | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [modalOpen, setModalOpen] = useState(false)
  const [selectedEntryId, setSelectedEntryId] = useState<number | null>(null)

  const handleOpenChange = async (open: boolean) => {
    setIsOpen(open)

    // Lazy-load data when opening
    if (open && !ledgerData && !isLoading) {
      setIsLoading(true)
      setError(null)

      try {
        const response = await fetch(`/accounts/${accountId}/ledger?fiscal_year_id=${fiscalYearId}`)
        if (!response.ok) {
          throw new Error('Failed to fetch ledger data')
        }
        const data = await response.json()
        setLedgerData(data)
      } catch (err) {
        console.error('Error loading ledger data:', err)
        setError('Failed to load ledger data. Please try again.')
      } finally {
        setIsLoading(false)
      }
    }
  }

  const handleLineItemClick = (journalEntryId: number) => {
    setSelectedEntryId(journalEntryId)
    setModalOpen(true)
  }

  const handleModalSuccess = () => {
    setModalOpen(false)
    // Refresh ledger data after edit
    setLedgerData(null)
    // Re-fetch data
    if (isOpen) {
      handleOpenChange(true)
    }
    // Also reload the page to refresh balance sheet
    router.reload({ only: ['balanceSheet'] })
  }

  // Construct journal entry object from ledger data for editing
  const selectedEntry = useMemo<JournalEntry | null>(() => {
    if (!selectedEntryId || !ledgerData) return null

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
    <>
      <Popover open={isOpen} onOpenChange={handleOpenChange}>
        <PopoverTrigger asChild>{children}</PopoverTrigger>
        <PopoverContent
          className="w-[90vw] max-w-5xl max-h-[80vh] overflow-auto"
          side="left"
          align="start"
          sideOffset={8}
        >
          {isLoading && (
            <div className="flex items-center justify-center p-8">
              <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
            </div>
          )}

          {error && (
            <Alert variant="destructive">
              <AlertCircle className="h-4 w-4" />
              <AlertDescription>{error}</AlertDescription>
            </Alert>
          )}

          {ledgerData && (
            <div className="space-y-4">
              <div className="border-b pb-3">
                <h3 className="text-lg font-semibold">
                  {ledgerData.account.code} - {ledgerData.account.name}
                </h3>
                {ledgerData.fiscalYear && (
                  <p className="text-sm text-muted-foreground">
                    Fiscal Year {ledgerData.fiscalYear.year}
                  </p>
                )}
              </div>

              <AccountLedgerTable
                ledgerData={ledgerData}
                onLineItemClick={handleLineItemClick}
                compact={true}
              />
            </div>
          )}
        </PopoverContent>
      </Popover>

      {/* Nested Modal for Editing */}
      {selectedEntry && (
        <JournalEntryModal
          open={modalOpen}
          onOpenChange={setModalOpen}
          journalEntry={selectedEntry}
          recentAccounts={[]}
          fiscalYears={ledgerData?.fiscalYear ? [ledgerData.fiscalYear] : []}
          onSuccess={handleModalSuccess}
        />
      )}
    </>
  )
}
