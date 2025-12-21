import React from 'react'
import { formatCurrency, formatDate } from '@/utils/formatting'
import { AccountLedgerData } from '@/types/accounting'
import { cn } from '@/lib/utils'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { InfoIcon } from 'lucide-react'

interface AccountLedgerTableProps {
  ledgerData: AccountLedgerData
  onLineItemClick?: (journalEntryId: number) => void
  compact?: boolean // For popover vs full page
}

export function AccountLedgerTable({
  ledgerData,
  onLineItemClick,
  compact = false,
}: AccountLedgerTableProps) {
  if (ledgerData.lineItemGroups.length === 0) {
    return (
      <div className="p-8">
        <Alert>
          <InfoIcon className="h-4 w-4" />
          <AlertDescription>
            No transactions found for this account
            {ledgerData.fiscalYear && ` in fiscal year ${ledgerData.fiscalYear.year}`}.
          </AlertDescription>
        </Alert>
      </div>
    )
  }

  return (
    <div className={cn('w-full', !compact && 'overflow-x-auto')}>
      <table className="w-full">
        <thead className="bg-muted/50 border-b">
          <tr>
            <th className="text-left py-3 px-4 font-semibold text-sm">Date</th>
            <th className="text-left py-3 px-4 font-semibold text-sm">Account</th>
            <th className="text-left py-3 px-4 font-semibold text-sm">Description</th>
            <th className="text-right py-3 px-4 font-semibold text-sm">Debit</th>
            <th className="text-right py-3 px-4 font-semibold text-sm">Credit</th>
          </tr>
        </thead>
        <tbody>
          {ledgerData.lineItemGroups.map((group, groupIndex) => (
            <React.Fragment key={group.journalEntryId}>
              {group.lineItems.map((lineItem, itemIndex) => (
                <tr
                  key={lineItem.id}
                  className={cn(
                    'transition-colors',
                    onLineItemClick && 'hover:bg-accent/50 cursor-pointer',
                    itemIndex === 0 && groupIndex > 0 && 'border-t-2 border-border'
                  )}
                  onClick={() => onLineItemClick?.(group.journalEntryId)}
                >
                  {/* Show date only on first row of each group */}
                  <td className="py-2 px-4 text-sm">
                    {itemIndex === 0 && formatDate(group.bookingDate)}
                  </td>

                  {/* Account code and name */}
                  <td className="py-2 px-4">
                    <div className="flex flex-col">
                      <span className="font-mono text-xs text-muted-foreground">
                        {lineItem.accountCode}
                      </span>
                      <span className="text-sm">{lineItem.accountName}</span>
                    </div>
                  </td>

                  {/* Description: custom line item description or journal entry description */}
                  <td className="py-2 px-4 text-sm">
                    <div className="flex items-center gap-2">
                      <span>{lineItem.description || group.description}</span>
                      {lineItem.description && (
                        <span className="text-xs text-muted-foreground italic">
                          (Custom)
                        </span>
                      )}
                    </div>
                  </td>

                  {/* Debit amount */}
                  <td className="py-2 px-4 text-right font-mono text-sm">
                    {lineItem.direction === 'debit' ? formatCurrency(lineItem.amount) : ''}
                  </td>

                  {/* Credit amount */}
                  <td className="py-2 px-4 text-right font-mono text-sm">
                    {lineItem.direction === 'credit' ? formatCurrency(lineItem.amount) : ''}
                  </td>
                </tr>
              ))}
            </React.Fragment>
          ))}

          {/* Final balance row */}
          <tr className="border-t-2 border-primary font-semibold bg-muted/30">
            <td colSpan={3} className="text-right py-3 px-4">
              Final Balance:
            </td>
            <td colSpan={2} className="text-right font-mono py-3 px-4">
              {formatCurrency(ledgerData.balance)}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  )
}
