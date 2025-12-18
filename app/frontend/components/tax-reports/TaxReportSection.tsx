import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { formatCurrency } from '@/utils/formatting'
import type { TaxFormField } from '@/types/tax-reports'
import { TaxFormFieldRow } from './TaxFormFieldRow'

interface TaxReportSectionProps {
  title: string
  fields: TaxFormField[]
  subtotal?: number
  showFieldNumbers?: boolean
  editable?: boolean
  onFieldChange?: (key: string, value: number) => void
}

export function TaxReportSection({
  title,
  fields,
  subtotal,
  showFieldNumbers = true,
  editable = false,
  onFieldChange
}: TaxReportSectionProps) {
  if (fields.length === 0) {
    return null
  }

  return (
    <div className="space-y-2">
      <h3 className="text-lg font-semibold">{title}</h3>
      <Table>
        <TableHeader>
          <TableRow>
            {showFieldNumbers && <TableHead className="w-24">Field No.</TableHead>}
            <TableHead>Field Name</TableHead>
            <TableHead className="text-right">Amount</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {fields.map((field) => (
            <TaxFormFieldRow
              key={field.key}
              field={field}
              showFieldNumber={showFieldNumbers}
              editable={editable && field.editable}
              onValueChange={onFieldChange}
            />
          ))}
          {subtotal !== undefined && (
            <TableRow className="font-semibold border-t-2">
              {showFieldNumbers && <TableCell></TableCell>}
              <TableCell>Subtotal</TableCell>
              <TableCell className="text-right">{formatCurrency(subtotal)}</TableCell>
            </TableRow>
          )}
        </TableBody>
      </Table>
    </div>
  )
}
