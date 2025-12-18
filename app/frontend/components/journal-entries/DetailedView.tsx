import { TableRow, TableCell } from '@/components/ui/table'
import { Button } from '@/components/ui/button'
import { ChevronUp } from 'lucide-react'
import { formatCurrency } from '@/utils/formatting'
import type { JournalEntry } from '@/types/journal-entries'

interface DetailedViewProps {
  entry: JournalEntry
  backgroundColor: string
  showExpandToggle?: boolean
  onToggleExpand?: () => void
}

export function DetailedView({
  entry,
  backgroundColor,
  showExpandToggle = false,
  onToggleExpand,
}: DetailedViewProps) {
  return (
    <>
      {/* Line item rows */}
      {entry.lineItems.map((lineItem) => (
        <TableRow key={lineItem.id} className={backgroundColor}>
          <TableCell></TableCell>
          <TableCell className="pl-8 font-mono text-sm">
            {lineItem.accountCode}
          </TableCell>
          <TableCell>{lineItem.accountName}</TableCell>
          <TableCell className="text-sm text-muted-foreground">
            {lineItem.bankTransactionId && '(Bank transaction)'}
          </TableCell>
          <TableCell className="text-right font-mono text-red-600">
            {lineItem.direction === 'debit' && formatCurrency(lineItem.amount)}
          </TableCell>
          <TableCell className="text-right font-mono text-green-600">
            {lineItem.direction === 'credit' && formatCurrency(lineItem.amount)}
          </TableCell>
          <TableCell>
            {showExpandToggle && lineItem.id === entry.lineItems[0].id && (
              <Button
                size="sm"
                variant="ghost"
                onClick={onToggleExpand}
                className="h-6 w-6 p-0"
                title="Hide details"
              >
                <ChevronUp className="h-4 w-4" />
              </Button>
            )}
          </TableCell>
        </TableRow>
      ))}

      {/* Subtotal row */}
      <TableRow className={`border-b ${backgroundColor}`}>
        <TableCell colSpan={4} className="text-right text-sm font-medium">
          Subtotal:
        </TableCell>
        <TableCell className="text-right font-mono text-sm">
          {formatCurrency(
            entry.lineItems
              .filter((li) => li.direction === 'debit')
              .reduce((sum, li) => sum + li.amount, 0)
          )}
        </TableCell>
        <TableCell className="text-right font-mono text-sm">
          {formatCurrency(
            entry.lineItems
              .filter((li) => li.direction === 'credit')
              .reduce((sum, li) => sum + li.amount, 0)
          )}
        </TableCell>
        <TableCell></TableCell>
      </TableRow>
    </>
  )
}
