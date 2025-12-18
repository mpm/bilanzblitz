import { useState } from 'react'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import { Loader2, Eye } from 'lucide-react'
import { JournalEntryRow } from '@/components/journal-entries/JournalEntryRow'
import type { JournalEntry } from '@/types/journal-entries'

interface JournalEntryPopoverProps {
  journalEntryId: number
  children: React.ReactNode
}

export function JournalEntryPopover({ journalEntryId, children }: JournalEntryPopoverProps) {
  const [isOpen, setIsOpen] = useState(false)
  const [journalEntry, setJournalEntry] = useState<JournalEntry | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const handleOpenChange = async (open: boolean) => {
    setIsOpen(open)
    
    if (open && !journalEntry && !isLoading) {
      setIsLoading(true)
      setError(null)
      
      try {
        const response = await fetch(`/journal_entries/${journalEntryId}`)
        
        if (!response.ok) {
          if (response.status === 404) {
            setError('Journal entry not found')
          } else if (response.status === 403) {
            setError('Access denied')
          } else {
            setError('Failed to load journal entry')
          }
          return
        }
        
        const data = await response.json()
        setJournalEntry(data)
      } catch (err) {
        setError('Network error. Please try again.')
      } finally {
        setIsLoading(false)
      }
    }
  }

  return (
    <Popover open={isOpen} onOpenChange={handleOpenChange}>
      <PopoverTrigger asChild>
        {children}
      </PopoverTrigger>
      <PopoverContent 
        className="w-[90vw] max-w-4xl max-h-[80vh] overflow-auto" 
        side="left" 
        align="start"
        sideOffset={8}
      >
        <div className="space-y-4">
          <div className="flex items-center gap-2 pb-2 border-b">
            <Eye className="h-4 w-4" />
            <h3 className="font-semibold">Journal Entry Details</h3>
          </div>
          
          {isLoading && (
            <div className="flex items-center justify-center py-8">
              <Loader2 className="h-6 w-6 animate-spin" />
              <span className="ml-2 text-sm text-muted-foreground">Loading journal entry...</span>
            </div>
          )}
          
          {error && (
            <div className="text-center py-8">
              <div className="text-sm text-destructive">{error}</div>
            </div>
          )}
          
          {journalEntry && !isLoading && !error && (
            <div className="space-y-0">
              <JournalEntryRow
                entry={journalEntry}
                index={0}
                globalSimplifiedMode={false}
              />
            </div>
          )}
        </div>
      </PopoverContent>
    </Popover>
  )
}