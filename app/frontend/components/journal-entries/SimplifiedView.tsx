import { TableRow, TableCell } from '@/components/ui/table'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import {
  ShoppingCart,
  Euro,
  Globe,
  ArrowRight,
  ArrowLeft,
  Building2,
  ChevronDown,
  AlertCircle,
} from 'lucide-react'
import { formatCurrency } from '@/utils/formatting'
import type { JournalEntry, VatPattern } from '@/types/journal-entries'

interface SimplifiedViewProps {
  entry: JournalEntry
  pattern: VatPattern
  backgroundColor: string
  onToggleExpand?: () => void
}

export function SimplifiedView({
  pattern,
  backgroundColor,
  onToggleExpand,
}: SimplifiedViewProps) {
  return (
    <>
      <TableRow className={backgroundColor}>
        <TableCell colSpan={7} className="py-3">
          <div className="space-y-1">
            {pattern.type === 'vat_expense' && (
              <VatExpenseView pattern={pattern} onToggleExpand={onToggleExpand} />
            )}
            {pattern.type === 'vat_revenue' && (
              <VatRevenueView pattern={pattern} onToggleExpand={onToggleExpand} />
            )}
            {pattern.type === 'reverse_charge' && (
              <ReverseChargeView pattern={pattern} onToggleExpand={onToggleExpand} />
            )}
          </div>
        </TableCell>
      </TableRow>
    </>
  )
}

function VatExpenseView({
  pattern,
  onToggleExpand,
}: {
  pattern: VatPattern
  onToggleExpand?: () => void
}) {
  if (!pattern.mainAccount || !pattern.bankAccount || !pattern.vatAccount) {
    return null
  }

  return (
    <div>
      <div className="flex items-center gap-2 text-sm">
        <ShoppingCart className="h-4 w-4 text-muted-foreground" />
        <span className="font-medium">{pattern.mainAccount.accountName}</span>
        <span className="font-mono text-sm">
          ({formatCurrency(pattern.netAmount!)})
        </span>
        <ArrowRight className="h-4 w-4 text-muted-foreground" />
        <Building2 className="h-4 w-4 text-muted-foreground" />
        <span>{pattern.bankAccount.accountName}</span>
        <Badge variant="outline" className="text-blue-600 border-blue-600">
          {pattern.vatRate}% USt ({formatCurrency(pattern.vatAmount!)})
        </Badge>
        {onToggleExpand && (
          <Button
            size="sm"
            variant="ghost"
            onClick={onToggleExpand}
            className="h-6 w-6 p-0 ml-auto"
            title="Show all line items"
          >
            <ChevronDown className="h-4 w-4" />
          </Button>
        )}
      </div>
      <div className="text-xs text-muted-foreground pl-6">
        Konto {pattern.mainAccount.accountCode} • Vorsteuer{' '}
        {pattern.vatAccount.accountCode}
      </div>
    </div>
  )
}

function VatRevenueView({
  pattern,
  onToggleExpand,
}: {
  pattern: VatPattern
  onToggleExpand?: () => void
}) {
  if (!pattern.mainAccount || !pattern.bankAccount || !pattern.vatAccount) {
    return null
  }

  return (
    <div>
      <div className="flex items-center gap-2 text-sm">
        <Euro className="h-4 w-4 text-green-600" />
        <span className="font-medium">{pattern.mainAccount.accountName}</span>
        <span className="font-mono text-sm">
          ({formatCurrency(pattern.netAmount!)})
        </span>
        <ArrowLeft className="h-4 w-4 text-muted-foreground" />
        <Building2 className="h-4 w-4 text-muted-foreground" />
        <span>{pattern.bankAccount.accountName}</span>
        <Badge variant="outline" className="text-blue-600 border-blue-600">
          {pattern.vatRate}% USt ({formatCurrency(pattern.vatAmount!)})
        </Badge>
        {onToggleExpand && (
          <Button
            size="sm"
            variant="ghost"
            onClick={onToggleExpand}
            className="h-6 w-6 p-0 ml-auto"
            title="Show all line items"
          >
            <ChevronDown className="h-4 w-4" />
          </Button>
        )}
      </div>
      <div className="text-xs text-muted-foreground pl-6">
        Konto {pattern.mainAccount.accountCode} • Umsatzsteuer{' '}
        {pattern.vatAccount.accountCode}
      </div>
    </div>
  )
}

function ReverseChargeView({
  pattern,
  onToggleExpand,
}: {
  pattern: VatPattern
  onToggleExpand?: () => void
}) {
  if (
    !pattern.mainAccount ||
    !pattern.bankAccount ||
    !pattern.reverseChargeInput ||
    !pattern.reverseChargeOutput
  ) {
    return null
  }

  return (
    <div>
      <div className="flex items-center gap-2 text-sm">
        <Globe className="h-4 w-4 text-amber-600" />
        <span className="font-medium">{pattern.mainAccount.accountName}</span>
        <span className="font-mono text-sm">
          ({formatCurrency(pattern.grossAmount)})
        </span>
        <ArrowRight className="h-4 w-4 text-muted-foreground" />
        <Building2 className="h-4 w-4 text-muted-foreground" />
        <span>{pattern.bankAccount.accountName}</span>
        {onToggleExpand && (
          <Button
            size="sm"
            variant="ghost"
            onClick={onToggleExpand}
            className="h-6 w-6 p-0 ml-auto"
            title="Show all line items"
          >
            <ChevronDown className="h-4 w-4" />
          </Button>
        )}
      </div>
      <div className="flex items-center gap-2 text-xs pl-6">
        <AlertCircle className="h-3 w-3 text-amber-600" />
        <span className="text-muted-foreground">
          Reverse Charge (§13b UStG): {formatCurrency(pattern.vatAmount!)}{' '}
          Vorsteuer ({pattern.reverseChargeInput.accountCode}),{' '}
          {formatCurrency(pattern.vatAmount!)} USt (
          {pattern.reverseChargeOutput.accountCode})
        </span>
      </div>
    </div>
  )
}
