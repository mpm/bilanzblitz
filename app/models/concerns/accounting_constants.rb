module AccountingConstants
  # Account types for German accounting
  # asset, liability, equity, revenue, expense
  ACCOUNT_TYPES = %w[asset liability equity revenue expense].freeze

  # SKR03 closing accounts (9000-series)
  # Used for Eröffnungsbilanzkonto (EBK) and Schlussbilanzkonto (SBK)
  CLOSING_ACCOUNTS = {
    ebk_sbk: "9000",               # Saldenvorträge, Sachkonten
    ebk_debtors: "9008",           # Saldenvorträge, Debitoren
    ebk_creditors: "9009",         # Saldenvorträge, Kreditoren
    summary_carryforward: "9090"   # Summenvortragskonto
  }.freeze

  # Journal entry types
  ENTRY_TYPES = %w[normal opening closing].freeze
end
