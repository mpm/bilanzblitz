import React from 'react'
import { formatCurrency } from '@/utils/formatting'
import { BalanceSheetSectionNested } from '@/types/accounting'

interface BalanceSheetSectionProps {
  title: string
  sections: Record<string, BalanceSheetSectionNested>
  total: number
  showPreviousYear?: boolean
}

// Helper to convert Roman numerals
const getRomanNumeral = (index: number): string => {
  const numerals = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X']
  return numerals[index] || `${index + 1}`
}

// Helper to get letter prefix
const getLetterPrefix = (index: number): string => {
  return String.fromCharCode(65 + index) // A, B, C, ...
}

export const BalanceSheetSection = ({
  title,
  sections,
  total,
  showPreviousYear = false,
}: BalanceSheetSectionProps) => {
  // Recursive function to render nested sections
  const renderNestedSection = (
    section: BalanceSheetSectionNested,
    depth: number,
    prefix: string,
    showPreviousYear: boolean
  ): React.ReactNode[] => {
    const rows: React.ReactNode[] = []

    // Skip empty sections (no accounts and no total)
    if (section.total === 0 && section.accounts.length === 0) {
      return []
    }

    // Section header with appropriate indentation
    const indentClass = depth === 0 ? '' : depth === 1 ? 'pl-4' : depth === 2 ? 'pl-8' : 'pl-12'
    const fontClass = depth === 0 ? 'font-semibold text-base' : depth === 1 ? 'font-medium text-sm' : 'text-sm'

    rows.push(
      <tr key={`${section.sectionKey}-header`} className="border-t border-border">
        <td
          colSpan={showPreviousYear ? 3 : 2}
          className={`py-2 pt-3 ${indentClass} ${fontClass}`}
        >
          {prefix && `${prefix}. `}{section.sectionName}
        </td>
      </tr>
    )

    // Render accounts at this level
    section.accounts.forEach((account) => {
      rows.push(
        <tr
          key={`${section.sectionKey}-${account.code}`}
          className="hover:bg-accent/50 transition-colors"
        >
          <td className={`py-1.5 ${depth === 0 ? 'pl-6' : depth === 1 ? 'pl-10' : depth === 2 ? 'pl-14' : 'pl-18'}`}>
            <div className="flex items-center gap-2">
              <span className="font-mono text-xs text-muted-foreground">
                {account.code}
              </span>
              <span className="text-sm">{account.name}</span>
            </div>
          </td>
          <td className="py-1.5 text-right font-mono text-sm">
            {formatCurrency(account.balance)}
          </td>
          {showPreviousYear && (
            <td className="py-1.5 text-right font-mono text-sm text-muted-foreground">
              {formatCurrency(0)}
            </td>
          )}
        </tr>
      )
    })

    // Recursively render children
    if (section.children && section.children.length > 0) {
      section.children.forEach((child, index) => {
        const childPrefix = depth === 0 ? getRomanNumeral(index) : depth === 1 ? `${index + 1}` : ''
        const childRows = renderNestedSection(child, depth + 1, childPrefix, showPreviousYear)
        rows.push(...childRows)
      })

      // Show section subtotal if it has children
      if (section.children.length > 0 && section.total !== 0) {
        rows.push(
          <tr key={`${section.sectionKey}-subtotal`} className="border-t border-border/50">
            <td className={`py-1.5 text-sm font-medium ${indentClass}`}>
              Summe {section.sectionName}
            </td>
            <td className="py-1.5 text-right font-mono text-sm font-medium">
              {formatCurrency(section.total)}
            </td>
            {showPreviousYear && (
              <td className="py-1.5 text-right font-mono text-sm text-muted-foreground">
                {formatCurrency(0)}
              </td>
            )}
          </tr>
        )
      }
    }

    return rows
  }

  // Render all top-level sections
  const sectionEntries = Object.values(sections)
  const hasAccounts = sectionEntries.some((s) => s.totalAccountCount > 0)

  return (
    <div className="flex flex-col h-full">
      <h2 className="text-2xl font-semibold mb-4">{title}</h2>
      <table className="w-full h-full" style={{ borderCollapse: 'collapse' }}>
        <thead>
          <tr className="border-b-2 border-border">
            <th className="text-left py-2 font-semibold text-sm">Position</th>
            <th className="text-right py-2 font-semibold text-sm w-32">
              Current Year
            </th>
            {showPreviousYear && (
              <th className="text-right py-2 font-semibold text-sm w-32">
                Previous Year
              </th>
            )}
          </tr>
        </thead>
        <tbody>
          {!hasAccounts ? (
            <tr>
              <td
                colSpan={showPreviousYear ? 3 : 2}
                className="text-center py-6 text-muted-foreground text-sm"
              >
                No accounts with balances
              </td>
            </tr>
          ) : (
            <>
              {sectionEntries.map((section, index) => {
                const prefix = getLetterPrefix(index)
                const rows = renderNestedSection(section, 0, prefix, showPreviousYear)
                return <React.Fragment key={section.sectionKey}>{rows}</React.Fragment>
              })}
              {/* Spacer row to push footer to bottom */}
              <tr style={{ height: '100%' }}>
                <td colSpan={showPreviousYear ? 3 : 2}></td>
              </tr>
            </>
          )}
        </tbody>
        <tfoot>
          <tr className="border-t-2 border-border font-bold">
            <td className="py-3 text-lg">Total</td>
            <td className="py-3 text-right font-mono text-lg">
              {formatCurrency(total)}
            </td>
            {showPreviousYear && (
              <td className="py-3 text-right font-mono text-lg text-muted-foreground">
                {formatCurrency(0)}
              </td>
            )}
          </tr>
        </tfoot>
      </table>
    </div>
  )
}
