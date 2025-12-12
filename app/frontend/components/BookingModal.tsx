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
import { Switch } from '@/components/ui/switch'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { AccountSearch } from '@/components/AccountSearch'
import { Loader2, AlertCircle } from 'lucide-react'

interface Account {
  id: number
  code: string
  name: string
  accountType: string
  taxRate: number
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

export function BookingModal({
  open,
  onOpenChange,
  transaction,
  recentAccounts,
  onSuccess,
}: BookingModalProps) {
  const [selectedAccount, setSelectedAccount] = useState<Account | null>(null)
  const [description, setDescription] = useState('')
  const [vatSplit, setVatSplit] = useState(false)
  const [vatRate, setVatRate] = useState<number>(19)
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  // Reset form when transaction changes
  useEffect(() => {
    if (transaction) {
      setDescription(transaction.remittanceInformation || '')
      setSelectedAccount(null)
      setVatSplit(false)
      setVatRate(19)
      setError(null)
    }
  }, [transaction])

  // Auto-enable VAT split when selecting account with tax rate
  useEffect(() => {
    if (selectedAccount && selectedAccount.taxRate > 0) {
      setVatSplit(true)
      setVatRate(selectedAccount.taxRate)
    }
  }, [selectedAccount])

  const calculateSplit = () => {
    if (!transaction || !vatSplit) return null

    const grossAmount = Math.abs(transaction.amount)
    const vatRateDecimal = vatRate / 100
    const netAmount = grossAmount / (1 + vatRateDecimal)
    const vatAmount = grossAmount - netAmount

    return {
      gross: grossAmount,
      net: netAmount.toFixed(2),
      vat: vatAmount.toFixed(2),
    }
  }

  const handleSubmit = async () => {
    if (!transaction || !selectedAccount) return

    setIsLoading(true)
    setError(null)

    try {
      const response = await fetch('/journal_entries', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '',
        },
        body: JSON.stringify({
          bank_transaction_id: transaction.id,
          journal_entry: {
            account_id: selectedAccount.id,
            description,
            vat_split: vatSplit,
            vat_rate: vatSplit ? vatRate : 0,
          },
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

  const formatAmount = (amount: number, currency: string) => {
    return new Intl.NumberFormat('de-DE', {
      style: 'currency',
      currency,
    }).format(amount)
  }

  const split = calculateSplit()
  const isExpense = transaction && transaction.amount < 0
  const vatAccountCode = isExpense
    ? (vatRate >= 19 ? '1576' : '1571')
    : (vatRate >= 19 ? '1776' : '1771')
  const vatAccountName = isExpense ? 'Vorsteuer' : 'Umsatzsteuer'

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

            {/* VAT Split Toggle */}
            <div className="flex items-center justify-between">
              <div className="space-y-0.5">
                <Label htmlFor="vat-split">Split VAT</Label>
                <p className="text-sm text-muted-foreground">
                  Automatically separate {isExpense ? 'input' : 'output'} tax
                </p>
              </div>
              <Switch
                id="vat-split"
                checked={vatSplit}
                onCheckedChange={setVatSplit}
              />
            </div>

            {/* VAT Rate Selection */}
            {vatSplit && (
              <div className="space-y-2">
                <Label>VAT Rate</Label>
                <div className="flex gap-2">
                  <Button
                    type="button"
                    variant={vatRate === 19 ? 'default' : 'outline'}
                    size="sm"
                    onClick={() => setVatRate(19)}
                  >
                    19%
                  </Button>
                  <Button
                    type="button"
                    variant={vatRate === 7 ? 'default' : 'outline'}
                    size="sm"
                    onClick={() => setVatRate(7)}
                  >
                    7%
                  </Button>
                </div>
              </div>
            )}

            {/* Split Preview */}
            {vatSplit && split && selectedAccount && (
              <div className="rounded-lg border p-4 space-y-2 text-sm">
                <div className="font-medium">Booking Preview</div>
                <div className="flex justify-between">
                  <span>{selectedAccount.code} {selectedAccount.name}</span>
                  <span>{split.net} EUR</span>
                </div>
                <div className="flex justify-between">
                  <span>{vatAccountCode} {vatAccountName} {vatRate}%</span>
                  <span>{split.vat} EUR</span>
                </div>
                <div className="border-t pt-2 flex justify-between font-medium">
                  <span>Total</span>
                  <span>{split.gross.toFixed(2)} EUR</span>
                </div>
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
