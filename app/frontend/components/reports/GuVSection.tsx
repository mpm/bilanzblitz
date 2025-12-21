import React from 'react'
import { formatCurrency } from '@/utils/formatting'
import { GuVData } from '@/types/accounting'

interface GuVSectionProps {
  guv: GuVData
  showPreviousYear?: boolean
}

export const GuVSection = ({ guv, showPreviousYear = false }: GuVSectionProps) => {
  return (
    <div className="mt-12">
      <h2 className="text-2xl font-semibold mb-2">
        Gewinn- und Verlustrechnung (GuV)
      </h2>
      <p className="text-sm text-muted-foreground mb-4">
        Gesamtkostenverfahren nach § 275 Abs. 2 HGB
      </p>

      <table className="w-full" style={{ borderCollapse: 'collapse' }}>
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
          {guv.sections.map((section) => (
            <React.Fragment key={section.key}>
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
                    key={account.code}
                    className="hover:bg-accent/50 transition-colors"
                  >
                    <td className="py-2 pl-6">
                      <div className="flex items-center gap-2">
                        <span className="font-mono text-sm text-muted-foreground">
                          {account.code}
                        </span>
                        <span className="text-sm">{account.name}</span>
                      </div>
                    </td>
                    <td
                      className={`py-2 text-right font-mono text-sm ${
                        section.displayType === 'negative' ? 'text-red-600' : ''
                      }`}
                    >
                      {formatCurrency(Math.abs(account.balance))}
                    </td>
                    {showPreviousYear && (
                      <td className="py-2 text-right font-mono text-sm text-muted-foreground">
                        {formatCurrency(0)}
                      </td>
                    )}
                  </tr>
                ))
              )}

              {/* Section Subtotal */}
              <tr className="border-t border-border bg-accent/20">
                <td className="py-2 pl-6 font-semibold text-sm">Subtotal</td>
                <td
                  className={`py-2 text-right font-mono text-sm font-semibold ${
                    section.displayType === 'negative' ? 'text-red-600' : ''
                  }`}
                >
                  {formatCurrency(Math.abs(section.subtotal))}
                </td>
                {showPreviousYear && (
                  <td className="py-2 text-right font-mono text-sm font-semibold text-muted-foreground">
                    {formatCurrency(0)}
                  </td>
                )}
              </tr>
            </React.Fragment>
          ))}

          {/* Net Income/Loss */}
          <tr className="border-t-2 border-border font-bold bg-accent/30">
            <td className="py-4 text-lg">{guv.netIncomeLabel}</td>
            <td
              className={`py-4 text-right font-mono text-lg ${
                guv.netIncome < 0 ? 'text-red-600' : 'text-green-600'
              }`}
            >
              {formatCurrency(Math.abs(guv.netIncome))}
            </td>
            {showPreviousYear && (
              <td className="py-4 text-right font-mono text-lg text-muted-foreground">
                {formatCurrency(0)}
              </td>
            )}
          </tr>
        </tbody>
      </table>
    </div>
  )
}
