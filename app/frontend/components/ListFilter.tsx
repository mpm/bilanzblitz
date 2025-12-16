import React from 'react'
import { Card } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Checkbox } from '@/components/ui/checkbox'
import { Button } from '@/components/ui/button'
import { ArrowUp, ArrowDown } from 'lucide-react'

export interface FilterState {
  fiscalYearId: number | null // null = "All"
  sortOrder: 'asc' | 'desc'
  hideFilteredStatus: boolean // e.g., hide booked, hide posted
  searchText: string
}

export interface FilterConfig {
  showFiscalYearFilter?: boolean
  showSortOrder?: boolean
  showStatusFilter?: boolean
  showTextSearch?: boolean
  statusFilterLabel?: string // e.g., "Hide booked transactions", "Hide posted entries"
  statusFilterDescription?: string // Additional context for the status filter
  searchPlaceholder?: string // e.g., "Search transactions...", "Search entries..."
}

interface FiscalYear {
  id: number
  startDate: string
  endDate: string
  label?: string
}

interface ListFilterProps {
  config: FilterConfig
  fiscalYears?: FiscalYear[]
  value: FilterState
  onChange: (newState: FilterState) => void
}

export function ListFilter({ config, fiscalYears = [], value, onChange }: ListFilterProps) {
  const handleFiscalYearChange = (fiscalYearIdStr: string) => {
    const fiscalYearId = fiscalYearIdStr === 'all' ? null : parseInt(fiscalYearIdStr, 10)
    onChange({ ...value, fiscalYearId })
  }

  const handleSortOrderToggle = () => {
    onChange({ ...value, sortOrder: value.sortOrder === 'asc' ? 'desc' : 'asc' })
  }

  const handleStatusFilterChange = (checked: boolean) => {
    onChange({ ...value, hideFilteredStatus: checked })
  }

  const handleSearchChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    onChange({ ...value, searchText: e.target.value })
  }

  // Don't render if no filters are enabled
  const hasAnyFilter = config.showFiscalYearFilter || config.showSortOrder || config.showStatusFilter || config.showTextSearch
  if (!hasAnyFilter) {
    return null
  }

  return (
    <Card className="p-4 mb-4">
      <div className="flex flex-wrap gap-4 items-end">
        {/* Fiscal Year Filter */}
        {config.showFiscalYearFilter && fiscalYears.length > 0 && (
          <div className="flex-1 min-w-[200px]">
            <Label htmlFor="fiscal-year-filter">Fiscal Year</Label>
            <Select
              value={value.fiscalYearId?.toString() || 'all'}
              onValueChange={handleFiscalYearChange}
            >
              <SelectTrigger id="fiscal-year-filter">
                <SelectValue placeholder="Select fiscal year" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Years</SelectItem>
                {fiscalYears.map((fy) => (
                  <SelectItem key={fy.id} value={fy.id.toString()}>
                    {fy.label || `${fy.startDate} - ${fy.endDate}`}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        )}

        {/* Text Search */}
        {config.showTextSearch && (
          <div className="flex-1 min-w-[200px]">
            <Label htmlFor="search-filter">Search</Label>
            <Input
              id="search-filter"
              type="text"
              placeholder={config.searchPlaceholder || 'Search...'}
              value={value.searchText}
              onChange={handleSearchChange}
            />
          </div>
        )}

        {/* Sort Order Toggle */}
        {config.showSortOrder && (
          <div>
            <Label htmlFor="sort-order-toggle" className="block mb-2">Sort by Date</Label>
            <Button
              id="sort-order-toggle"
              variant="outline"
              size="default"
              onClick={handleSortOrderToggle}
              className="w-full"
            >
              {value.sortOrder === 'asc' ? (
                <>
                  <ArrowUp className="mr-2 h-4 w-4" />
                  Oldest First
                </>
              ) : (
                <>
                  <ArrowDown className="mr-2 h-4 w-4" />
                  Newest First
                </>
              )}
            </Button>
          </div>
        )}

        {/* Status Filter (Checkbox) */}
        {config.showStatusFilter && config.statusFilterLabel && (
          <div className="flex items-center space-x-2">
            <Checkbox
              id="status-filter"
              checked={value.hideFilteredStatus}
              onCheckedChange={handleStatusFilterChange}
            />
            <Label
              htmlFor="status-filter"
              className="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70 cursor-pointer"
            >
              {config.statusFilterLabel}
            </Label>
          </div>
        )}
      </div>

      {/* Optional description for status filter */}
      {config.showStatusFilter && config.statusFilterDescription && value.hideFilteredStatus && (
        <div className="mt-2 text-sm text-muted-foreground">
          {config.statusFilterDescription}
        </div>
      )}
    </Card>
  )
}
