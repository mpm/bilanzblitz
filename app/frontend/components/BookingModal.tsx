import { useState, useEffect } from 'react'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { AccountSearch } from '@/components/AccountSearch'
import { Loader2, AlertCircle } from 'lucide-react'
import { formatAmount } from '@/utils/formatting'

interface Account {
  id: number | null
  code: string
  name: string
  accountType: string
  taxRate: number
  fromTemplate?: boolean
}

interface Transaction {
  id: number
  bookingDate: string
  amount: number
  currency: string
  remittanceInformation: string | null
  counterpartyName: string | null
}

interface BookingModalProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  transaction: Transaction | null
  recentAccounts: Account[]
  onSuccess: () => void
}

type VatMode = 'none' | 'vat_19' | 'vat_7' | 'reverse_charge'

export function BookingModal({
  open,
  onOpenChange,
  transaction,
  recentAccounts,
  onSuccess,
}: BookingModalProps) {
  const [selectedAccount, setSelectedAccount] = useState<Account | null>(null)
  const [description, setDescription] = useState('')
  const [vatMode, setVatMode] = useState<VatMode>('none')
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  // Reset form when transaction changes
  useEffect(() => {
    if (transaction) {
      setDescription(transaction.remittanceInformation || '')
      setSelectedAccount(null)
      setVatMode('none')
      setError(null)
    }
  }, [transaction])

  // Auto-enable VAT when selecting account with tax rate
  useEffect(() => {
    if (selectedAccount && selectedAccount.taxRate > 0) {
      if (selectedAccount.taxRate >= 19) {
        setVatMode('vat_19')
      } else if (selectedAccount.taxRate >= 7) {
        setVatMode('vat_7')
      }
    }
  }, [selectedAccount])

  const calculateSplit = () => {
    if (!transaction || vatMode === 'none') return null

    const grossAmount = Math.abs(transaction.amount)

    if (vatMode === 'reverse_charge') {
      // Reverse charge: full amount to main account, plus separate VAT entries
      const vatAmount = (grossAmount * 0.19).toFixed(2)
      return {
        mode: 'reverse_charge' as const,
        gross: grossAmount,
        mainAmount: grossAmount.toFixed(2),
        vatAmount,
      }
    }

    // Standard VAT: split gross into net + VAT
    const vatRate = vatMode === 'vat_19' ? 19 : 7
    const vatRateDecimal = vatRate / 100
    const netAmount = grossAmount / (1 + vatRateDecimal)
    const vatAmount = grossAmount - netAmount

    return {
      mode: 'standard' as const,
      gross: grossAmount,
      net: netAmount.toFixed(2),
      vat: vatAmount.toFixed(2),
      vatRate,
    }
  }

  const handleSubmit = async () => {
    if (!transaction || !selectedAccount) return

    setIsLoading(true)
    setError(null)

    try {
      // Prepare journal entry parameters based on VAT mode
      const journalEntryParams: any = {
        account_code: selectedAccount.code,
        description,
        vat_mode: vatMode,
      }

      // For backward compatibility, also send vat_split and vat_rate
      if (vatMode === 'vat_19' || vatMode === 'vat_7') {
        journalEntryParams.vat_split = true
        journalEntryParams.vat_rate = vatMode === 'vat_19' ? 19 : 7
      } else if (vatMode === 'reverse_charge') {
        journalEntryParams.vat_split = false
        journalEntryParams.vat_rate = 0
      } else {
        journalEntryParams.vat_split = false
        journalEntryParams.vat_rate = 0
      }

      const response = await fetch('/journal_entries', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '',
        },
        body: JSON.stringify({
          bank_transaction_id: transaction.id,
          journal_entry: journalEntryParams,
        }),
      })

      const data = await response.json()

      if (data.success) {
        onSuccess()
        onOpenChange(false)
      } else {
        setError(data.errors?.join(', ') || 'Failed to create booking')
      }
    } catch (err) {
      setError('An error occurred while creating the booking')
    } finally {
      setIsLoading(false)
    }
  }

  const split = calculateSplit()
  const isExpense = transaction && transaction.amount < 0

  // Determine VAT account codes based on mode
  const getVatAccountInfo = () => {
    if (vatMode === 'reverse_charge') {
      return {
        inputCode: '1577',
        inputName: 'Abziehbare Vorsteuer § 13b UStG 19%',
        outputCode: '1787',
        outputName: 'Umsatzsteuer nach § 13b UStG 19%',
      }
    }

    const vatRate = (split && 'vatRate' in split ? split.vatRate : 19) ?? 19
    const vatAccountCode = isExpense
      ? (vatRate >= 19 ? '1576' : '1571')
      : (vatRate >= 19 ? '1776' : '1771')
    const vatAccountName = isExpense ? `Vorsteuer ${vatRate}%` : `Umsatzsteuer ${vatRate}%`

    return { vatAccountCode, vatAccountName }
  }

  const vatInfo = getVatAccountInfo()

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-lg">
        <DialogHeader>
          <DialogTitle>Book Transaction</DialogTitle>
          <DialogDescription>
            Create a journal entry for this bank transaction
          </DialogDescription>
        </DialogHeader>

        {transaction && (
          <div className="space-y-6">
            {/* Transaction Summary */}
            <div className="rounded-lg border p-4 bg-muted/50">
              <div className="flex justify-between items-start">
                <div>
                  <p className="font-medium">{transaction.counterpartyName || 'Unknown'}</p>
                  <p className="text-sm text-muted-foreground truncate max-w-[300px]">
                    {transaction.remittanceInformation}
                  </p>
                </div>
                <div className={`text-lg font-semibold ${
                  transaction.amount >= 0 ? 'text-green-600' : 'text-red-600'
                }`}>
                  {formatAmount(transaction.amount, transaction.currency)}
                </div>
              </div>
            </div>

            {error && (
              <Alert variant="destructive">
                <AlertCircle className="h-4 w-4" />
                <AlertDescription>{error}</AlertDescription>
              </Alert>
            )}

            {/* Account Selection */}
            <div className="space-y-2">
              <Label>Counter Account</Label>
              <AccountSearch
                recentAccounts={recentAccounts}
                selectedAccount={selectedAccount}
                onSelect={setSelectedAccount}
              />
            </div>

            {/* Description */}
            <div className="space-y-2">
              <Label htmlFor="description">Description</Label>
              <Input
                id="description"
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                placeholder="Booking description..."
              />
            </div>

            {/* VAT Mode Selection */}
            <div className="space-y-2">
              <Label htmlFor="vat-mode">VAT Handling</Label>
              <Select value={vatMode} onValueChange={(value) => setVatMode(value as VatMode)}>
                <SelectTrigger id="vat-mode">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="none">No VAT</SelectItem>
                  <SelectItem value="vat_19">19% VAT</SelectItem>
                  <SelectItem value="vat_7">7% VAT</SelectItem>
                  <SelectItem value="reverse_charge">Reverse Charge §13b (19%)</SelectItem>
                </SelectContent>
              </Select>
              <p className="text-sm text-muted-foreground">
                {vatMode === 'none' && 'Transaction without VAT handling'}
                {vatMode === 'vat_19' && 'Split transaction with 19% VAT'}
                {vatMode === 'vat_7' && 'Split transaction with 7% reduced VAT'}
                {vatMode === 'reverse_charge' && 'Reverse charge procedure according to §13b UStG'}
              </p>
            </div>

            {/* Booking Preview */}
            {vatMode !== 'none' && split && selectedAccount && (
              <div className="rounded-lg border p-4 space-y-2 text-sm">
                <div className="font-medium">Booking Preview</div>

                {split.mode === 'standard' && (
                  <>
                    <div className="flex justify-between">
                      <span>{selectedAccount.code} {selectedAccount.name}</span>
                      <span>{split.net} EUR</span>
                    </div>
                    <div className="flex justify-between">
                      <span>{vatInfo.vatAccountCode} {vatInfo.vatAccountName}</span>
                      <span>{split.vat} EUR</span>
                    </div>
                    <div className="border-t pt-2 flex justify-between font-medium">
                      <span>Total</span>
                      <span>{split.gross.toFixed(2)} EUR</span>
                    </div>
                  </>
                )}

                {split.mode === 'reverse_charge' && (
                  <>
                    <div className="flex justify-between">
                      <span>{selectedAccount.code} {selectedAccount.name}</span>
                      <span>{split.mainAmount} EUR</span>
                    </div>
                    <div className="flex justify-between text-muted-foreground">
                      <span>{vatInfo.inputCode} {vatInfo.inputName}</span>
                      <span>{split.vatAmount} EUR</span>
                    </div>
                    <div className="flex justify-between text-muted-foreground">
                      <span>{vatInfo.outputCode} {vatInfo.outputName}</span>
                      <span>-{split.vatAmount} EUR</span>
                    </div>
                    <div className="border-t pt-2 flex justify-between font-medium">
                      <span>Total (Bank)</span>
                      <span>{split.gross.toFixed(2)} EUR</span>
                    </div>
                    <p className="text-xs text-muted-foreground italic mt-2">
                      VAT entries offset each other (net zero VAT effect)
                    </p>
                  </>
                )}
              </div>
            )}

            {/* Actions */}
            <div className="flex justify-end gap-2">
              <Button variant="outline" onClick={() => onOpenChange(false)}>
                Cancel
              </Button>
              <Button
                onClick={handleSubmit}
                disabled={!selectedAccount || isLoading}
              >
                {isLoading ? (
                  <>
                    <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                    Creating...
                  </>
                ) : (
                  'Create Booking'
                )}
              </Button>
            </div>
          </div>
        )}
      </DialogContent>
    </Dialog>
  )
}
