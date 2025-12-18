import { Fragment, useState, useMemo } from 'react'
import { TableRow, TableCell } from '@/components/ui/table'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { PenLine, Trash2 } from 'lucide-react'
import { formatDate } from '@/utils/formatting'
import { detectVatPattern } from './VatPatternDetector'
import { SimplifiedView } from './SimplifiedView'
import { DetailedView } from './DetailedView'
import type { JournalEntry } from '@/types/journal-entries'

interface JournalEntryRowProps {
  entry: JournalEntry
  index: number
  globalSimplifiedMode: boolean
  onEdit?: (entryId: number) => void
  onDelete?: (entryId: number) => void
}

export function JournalEntryRow({
  entry,
  index,
  globalSimplifiedMode,
  onEdit,
  onDelete,
}: JournalEntryRowProps) {
  const [isExpanded, setIsExpanded] = useState(false)

  // Detect VAT pattern using memoization to avoid re-computation
  const pattern = useMemo(() => detectVatPattern(entry), [entry])

  // Determine if we should show simplified view
  const showSimplified =
    globalSimplifiedMode && pattern.type !== 'none' && !isExpanded

  // Alternating background color for visual grouping
  const backgroundColor = index % 2 === 0 ? 'bg-muted/30' : 'bg-background'

  const handleToggleExpand = () => {
    setIsExpanded(!isExpanded)
  }

  return (
    <Fragment key={entry.id}>
      {/* Entry header row - Date, Description, Actions */}
      <TableRow className={`border-t-2 ${backgroundColor}`}>
        <TableCell className="font-medium" colSpan={2}>
          {formatDate(entry.bookingDate)}
        </TableCell>
        <TableCell colSpan={2}>{entry.description}</TableCell>
        <TableCell colSpan={2}></TableCell>
        <TableCell>
          <div className="flex gap-2">
            {!entry.postedAt && !entry.fiscalYearClosed && (
              <>
                {onEdit && (
                  <Button
                    size="sm"
                    variant="ghost"
                    onClick={() => onEdit(entry.id)}
                    title="Edit journal entry"
                  >
                    <PenLine className="h-4 w-4" />
                  </Button>
                )}
                {onDelete && (
                  <Button
                    size="sm"
                    variant="ghost"
                    onClick={() => onDelete(entry.id)}
                    title="Delete journal entry"
                  >
                    <Trash2 className="h-4 w-4" />
                  </Button>
                )}
              </>
            )}
            {entry.postedAt && <Badge variant="secondary">Posted</Badge>}
            {entry.fiscalYearClosed && !entry.postedAt && (
              <Badge variant="secondary">Closed FY</Badge>
            )}
          </div>
        </TableCell>
      </TableRow>

      {/* Content row(s) - Simplified or Detailed view */}
      {showSimplified ? (
        <SimplifiedView
          entry={entry}
          pattern={pattern}
          backgroundColor={backgroundColor}
          onToggleExpand={handleToggleExpand}
        />
      ) : (
        <DetailedView
          entry={entry}
          backgroundColor={backgroundColor}
          showExpandToggle={globalSimplifiedMode && pattern.type !== 'none'}
          onToggleExpand={handleToggleExpand}
        />
      )}
    </Fragment>
  )
}
