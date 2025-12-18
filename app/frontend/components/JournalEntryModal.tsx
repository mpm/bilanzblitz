import { router } from '@inertiajs/react'
import { useState, useEffect, useMemo } from 'react'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Badge } from '@/components/ui/badge'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { AccountSearch } from '@/components/AccountSearch'
import { Plus, Trash2, AlertCircle, Loader2 } from 'lucide-react'
import { formatCurrency } from '@/utils/formatting'
import type { JournalEntry } from '@/types/journal-entries'

interface FiscalYear {
  id: number
  year: number
  startDate: string
  endDate: string
  closed: boolean
}

interface Account {
  id: number | null
  code: string
  name: string
  accountType: string
  taxRate: number
  fromTemplate?: boolean
}

interface LineItemFormData {
  tempId: string
  account: Account | null
  debitAmount: string
  creditAmount: string
}

interface JournalEntryModalProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  journalEntry: JournalEntry | null
  recentAccounts: Account[]
  fiscalYears: FiscalYear[]
  onSuccess: () => void
}

export function JournalEntryModal({
  open,
  onOpenChange,
  journalEntry,
  recentAccounts,
  fiscalYears,
  onSuccess,
}: JournalEntryModalProps) {
  const [formData, setFormData] = useState({
    bookingDate: new Date().toISOString().split('T')[0],
    description: '',
  })
  const [lineItems, setLineItems] = useState<LineItemFormData[]>([
    createEmptyLineItem(),
    createEmptyLineItem(),
  ])
  const [errors, setErrors] = useState<string[]>([])
  const [isLoading, setIsLoading] = useState(false)

  // Create empty line item with unique temp ID
  function createEmptyLineItem(): LineItemFormData {
    return {
      tempId: crypto.randomUUID(),
      account: null,
      debitAmount: '',
      creditAmount: '',
    }
  }

  // Pre-populate form when editing
  useEffect(() => {
    if (journalEntry) {
      setFormData({
        bookingDate: journalEntry.bookingDate,
        description: journalEntry.description,
      })
      setLineItems(
        journalEntry.lineItems.map((li) => ({
          tempId: crypto.randomUUID(),
          account: {
            id: null,
            code: li.accountCode,
            name: li.accountName,
            accountType: '',
            taxRate: 0,
          },
          debitAmount: li.direction === 'debit' ? li.amount.toString() : '',
          creditAmount: li.direction === 'credit' ? li.amount.toString() : '',
        }))
      )
      setErrors([])
    } else {
      // Reset for create
      setFormData({
        bookingDate: new Date().toISOString().split('T')[0],
        description: '',
      })
      setLineItems([createEmptyLineItem(), createEmptyLineItem()])
      setErrors([])
    }
  }, [journalEntry, open])

  // Calculate balance
  const balance = useMemo(() => {
    const debits = lineItems.reduce(
      (sum, li) => sum + (parseFloat(li.debitAmount) || 0),
      0
    )
    const credits = lineItems.reduce(
      (sum, li) => sum + (parseFloat(li.creditAmount) || 0),
      0
    )
    return {
      debits,
      credits,
      balanced: Math.abs(debits - credits) < 0.01,
    }
  }, [lineItems])

  // Determine fiscal year for selected date
  const fiscalYearForDate = useMemo(() => {
    return fiscalYears.find(
      (fy) =>
        formData.bookingDate >= fy.startDate && formData.bookingDate <= fy.endDate
    )
  }, [formData.bookingDate, fiscalYears])

  // Add line item
  const handleAddLineItem = () => {
    setLineItems([...lineItems, createEmptyLineItem()])
  }

  // Remove line item
  const handleRemoveLineItem = (tempId: string) => {
    if (lineItems.length <= 2) {
      setErrors(['Minimum 2 line items required'])
      return
    }
    setLineItems(lineItems.filter((li) => li.tempId !== tempId))
    // Clear the error if it was about minimum line items
    setErrors(errors.filter((e) => !e.includes('Minimum 2')))
  }

  // Update line item field
  const updateLineItem = (
    tempId: string,
    field: keyof LineItemFormData,
    value: any
  ) => {
    setLineItems(
      lineItems.map((li) => (li.tempId === tempId ? { ...li, [field]: value } : li))
    )
  }

  // Handle debit amount change (auto-clear credit)
  const handleDebitChange = (tempId: string, value: string) => {
    setLineItems(
      lineItems.map((li) =>
        li.tempId === tempId
          ? { ...li, debitAmount: value, creditAmount: value ? '' : li.creditAmount }
          : li
      )
    )
  }

  // Handle credit amount change (auto-clear debit)
  const handleCreditChange = (tempId: string, value: string) => {
    setLineItems(
      lineItems.map((li) =>
        li.tempId === tempId
          ? { ...li, creditAmount: value, debitAmount: value ? '' : li.debitAmount }
          : li
      )
    )
  }

  // Validate form
  const validate = () => {
    const validationErrors: string[] = []

    if (!formData.bookingDate) {
      validationErrors.push('Booking date is required')
    }

    if (!formData.description.trim()) {
      validationErrors.push('Description is required')
    }

    if (lineItems.length < 2) {
      validationErrors.push('At least 2 line items required')
    }

    lineItems.forEach((li, idx) => {
      if (!li.account) {
        validationErrors.push(`Line ${idx + 1}: Account is required`)
      }

      const hasDebit = parseFloat(li.debitAmount) > 0
      const hasCredit = parseFloat(li.creditAmount) > 0

      if (!hasDebit && !hasCredit) {
        validationErrors.push(`Line ${idx + 1}: Amount is required`)
      }

      if (hasDebit && hasCredit) {
        validationErrors.push(`Line ${idx + 1}: Cannot have both debit and credit`)
      }
    })

    if (!balance.balanced) {
      validationErrors.push(
        `Debits (${formatCurrency(balance.debits)}) must equal credits (${formatCurrency(
          balance.credits
        )})`
      )
    }

    if (fiscalYearForDate?.closed) {
      validationErrors.push('Cannot save to closed fiscal year')
    }

    return validationErrors
  }

  // Submit form
  const handleSubmit = async () => {
    setIsLoading(true)
    setErrors([])

    const validationErrors = validate()
    if (validationErrors.length > 0) {
      setErrors(validationErrors)
      setIsLoading(false)
      return
    }

    const payload = {
      journal_entry: {
        booking_date: formData.bookingDate,
        description: formData.description,
        line_items: lineItems.map((li) => ({
          account_code: li.account!.code,
          amount: parseFloat(li.debitAmount || li.creditAmount),
          direction: li.debitAmount ? 'debit' : 'credit',
        })),
      },
    }

    const url = journalEntry
      ? `/journal_entries/${journalEntry.id}`
      : '/journal_entries'
    const method = journalEntry ? 'PUT' : 'POST'

    const csrfToken = document
      .querySelector('meta[name="csrf-token"]')
      ?.getAttribute('content')

    try {
      const response = await fetch(url, {
        method,
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken || '',
        },
        body: JSON.stringify(payload),
      })

      const data = await response.json()

      if (data.success) {
        onSuccess()
        router.reload()
      } else {
        setErrors(data.errors || ['Failed to save journal entry'])
      }
    } catch (error) {
      console.error('Journal entry save failed:', error)
      setErrors(['Network error. Please try again.'])
    } finally {
      setIsLoading(false)
    }
  }

  const canSave = balance.balanced && formData.description.trim() && lineItems.length >= 2

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-4xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>
            {journalEntry ? 'Edit Journal Entry' : 'New Journal Entry'}
          </DialogTitle>
          <DialogDescription>
            Create a manual journal entry with balanced debit and credit line items.
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-6">
          {/* Date and Description */}
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label htmlFor="bookingDate">Booking Date</Label>
              <Input
                id="bookingDate"
                type="date"
                value={formData.bookingDate}
                onChange={(e) =>
                  setFormData({ ...formData, bookingDate: e.target.value })
                }
              />
            </div>
            <div className="space-y-2">
              <Label>Fiscal Year</Label>
              <div className="flex items-center h-10">
                {fiscalYearForDate ? (
                  <Badge variant={fiscalYearForDate.closed ? 'secondary' : 'default'}>
                    {fiscalYearForDate.year}{' '}
                    {fiscalYearForDate.closed ? '(Closed)' : '(Open)'}
                  </Badge>
                ) : (
                  <span className="text-sm text-muted-foreground">
                    No fiscal year for this date
                  </span>
                )}
              </div>
            </div>
          </div>

          <div className="space-y-2">
            <Label htmlFor="description">Description</Label>
            <Input
              id="description"
              value={formData.description}
              onChange={(e) =>
                setFormData({ ...formData, description: e.target.value })
              }
              placeholder="Transaction description"
            />
          </div>

          {/* Line Items */}
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <Label className="text-base">Line Items</Label>
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={handleAddLineItem}
              >
                <Plus className="h-4 w-4 mr-2" />
                Add Line Item
              </Button>
            </div>

            <div className="border rounded-lg divide-y">
              {lineItems.map((lineItem) => (
                <div key={lineItem.tempId} className="p-4 space-y-3">
                  <div className="flex items-start gap-3">
                    <div className="flex-1 space-y-3">
                      {/* Account Selection */}
                      <div className="space-y-2">
                        <Label>Account</Label>
                        <AccountSearch
                          selectedAccount={lineItem.account}
                          onSelect={(account: Account | null) =>
                            updateLineItem(lineItem.tempId, 'account', account)
                          }
                          recentAccounts={recentAccounts}
                        />
                      </div>

                      {/* Debit and Credit */}
                      <div className="grid grid-cols-2 gap-4">
                        <div className="space-y-2">
                          <Label>Debit</Label>
                          <Input
                            type="number"
                            step="0.01"
                            min="0"
                            value={lineItem.debitAmount}
                            onChange={(e) =>
                              handleDebitChange(lineItem.tempId, e.target.value)
                            }
                            placeholder="0.00"
                            className="text-right font-mono"
                          />
                        </div>
                        <div className="space-y-2">
                          <Label>Credit</Label>
                          <Input
                            type="number"
                            step="0.01"
                            min="0"
                            value={lineItem.creditAmount}
                            onChange={(e) =>
                              handleCreditChange(lineItem.tempId, e.target.value)
                            }
                            placeholder="0.00"
                            className="text-right font-mono"
                          />
                        </div>
                      </div>
                    </div>

                    {/* Remove button */}
                    <Button
                      type="button"
                      variant="ghost"
                      size="icon"
                      onClick={() => handleRemoveLineItem(lineItem.tempId)}
                      disabled={lineItems.length <= 2}
                      title={
                        lineItems.length <= 2
                          ? 'Minimum 2 line items required'
                          : 'Remove line item'
                      }
                    >
                      <Trash2 className="h-4 w-4" />
                    </Button>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Balance Summary */}
          <div className="border rounded-lg p-4 bg-muted/50">
            <div className="flex justify-between items-center mb-2">
              <span className="font-medium">Total Debits:</span>
              <span className="font-mono text-red-600">
                {formatCurrency(balance.debits)}
              </span>
            </div>
            <div className="flex justify-between items-center mb-2">
              <span className="font-medium">Total Credits:</span>
              <span className="font-mono text-green-600">
                {formatCurrency(balance.credits)}
              </span>
            </div>
            <div className="flex justify-between items-center pt-2 border-t">
              <span className="font-semibold">Balance:</span>
              <div className="flex items-center gap-2">
                <span className="font-mono">
                  {formatCurrency(Math.abs(balance.debits - balance.credits))}
                </span>
                {balance.balanced ? (
                  <Badge variant="default" className="bg-green-600">
                    Balanced
                  </Badge>
                ) : (
                  <Badge variant="destructive">Unbalanced</Badge>
                )}
              </div>
            </div>
          </div>

          {/* Errors */}
          {errors.length > 0 && (
            <Alert variant="destructive">
              <AlertCircle className="h-4 w-4" />
              <AlertDescription>
                <ul className="list-disc list-inside space-y-1">
                  {errors.map((error, idx) => (
                    <li key={idx}>{error}</li>
                  ))}
                </ul>
              </AlertDescription>
            </Alert>
          )}
        </div>

        <DialogFooter>
          <Button
            type="button"
            variant="outline"
            onClick={() => onOpenChange(false)}
            disabled={isLoading}
          >
            Cancel
          </Button>
          <Button
            type="button"
            onClick={handleSubmit}
            disabled={!canSave || isLoading}
          >
            {isLoading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
            Save
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
