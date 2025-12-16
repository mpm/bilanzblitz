import React from 'react'
import { formatCurrency } from '@/utils/formatting'
import { AccountBalance } from '@/types/accounting'

interface Section {
  label: string
  accounts: AccountBalance[]
}

interface BalanceSheetSectionProps {
  title: string
  sections: Section[]
  total: number
  showPreviousYear?: boolean
}

export const BalanceSheetSection = ({
  title,
  sections,
  total,
  showPreviousYear = false,
}: BalanceSheetSectionProps) => {
  const hasAccounts = sections.some((section) => section.accounts.length > 0)

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
              {sections.map((section, sectionIndex) => (
                <React.Fragment key={sectionIndex}>
                  {/* Section Header */}
                  <tr className="border-t border-border">
                    <td
                      colSpan={showPreviousYear ? 3 : 2}
                      className="py-3 pt-4 font-semibold text-base"
                    >
                      {section.label}
                    </td>
                  </tr>
                  {/* Account Rows */}
                  {section.accounts.length === 0 ? (
                    <tr>
                      <td
                        colSpan={showPreviousYear ? 3 : 2}
                        className="pl-6 py-2 text-sm text-muted-foreground italic"
                      >
                        No accounts
                      </td>
                    </tr>
                  ) : (
                    section.accounts.map((account) => (
                      <tr
                        key={account.accountCode}
                        className="hover:bg-accent/50 transition-colors"
                      >
                        <td className="py-2 pl-6">
                          <div className="flex items-center gap-2">
                            <span className="font-mono text-sm text-muted-foreground">
                              {account.accountCode}
                            </span>
                            <span className="text-sm">{account.accountName}</span>
                          </div>
                        </td>
                        <td className="py-2 text-right font-mono text-sm">
                          {formatCurrency(account.balance)}
                        </td>
                        {showPreviousYear && (
                          <td className="py-2 text-right font-mono text-sm text-muted-foreground">
                            {formatCurrency(0)}
                          </td>
                        )}
                      </tr>
                    ))
                  )}
                </React.Fragment>
              ))}
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
