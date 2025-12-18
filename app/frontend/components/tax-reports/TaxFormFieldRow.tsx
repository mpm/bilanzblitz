import { TableCell, TableRow } from '@/components/ui/table'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { formatCurrency } from '@/utils/formatting'
import type { TaxFormField } from '@/types/tax-reports'
import { useState } from 'react'

interface TaxFormFieldRowProps {
  field: TaxFormField
  showFieldNumber?: boolean
  editable?: boolean
  onValueChange?: (key: string, value: number) => void
}

export function TaxFormFieldRow({
  field,
  showFieldNumber = true,
  editable = false,
  onValueChange
}: TaxFormFieldRowProps) {
  const [localValue, setLocalValue] = useState<string>(field.value.toString())

  const handleBlur = () => {
    const numValue = parseFloat(localValue) || 0
    if (onValueChange) {
      onValueChange(field.key, numValue)
    }
  }

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setLocalValue(e.target.value)
  }

  return (
    <TableRow>
      {showFieldNumber && (
        <TableCell>
          {field.fieldNumber && (
            <Badge variant="outline" className="font-mono">
              Kz {field.fieldNumber}
            </Badge>
          )}
        </TableCell>
      )}
      <TableCell>
        <div>
          <div className="font-medium">{field.name}</div>
          {field.description && (
            <div className="text-sm text-muted-foreground">{field.description}</div>
          )}
        </div>
      </TableCell>
      <TableCell className="text-right">
        {editable ? (
          <Input
            type="number"
            step="0.01"
            value={localValue}
            onChange={handleChange}
            onBlur={handleBlur}
            className="max-w-[150px] ml-auto text-right"
          />
        ) : (
          <span className="font-medium">{formatCurrency(field.value)}</span>
        )}
      </TableCell>
    </TableRow>
  )
}
