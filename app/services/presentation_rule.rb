# frozen_string_literal: true

# Presentation rules (Bilanzierungsregeln) determine the final Report Section where
# an account balance appears on the balance sheet based on the saldo direction.
#
# These rules decouple an account's logical identity (Semantic Category / CID)
# from its physical position on a report (Report Section).
#
# German Terminology:
# - H-Saldo = Haben-Saldo = Credit balance (liability side / credit-normal accounts)
# - S-Saldo = Soll-Saldo = Debit balance (asset side / debit-normal accounts)
# - Aktiva = Assets (left side of balance sheet)
# - Passiva = Liabilities + Equity (right side of balance sheet)
#
# Most accounts have a fixed position (asset_only, liability_only, etc.), but some
# accounts can appear on either side depending on their balance direction. This is
# common for:
# - Receivables that can become payables (and vice versa)
# - Bank accounts that can be overdrawn
# - Tax accounts that can be claims or liabilities
#
class PresentationRule
  # Rule identifier constants
  ASSET_ONLY = :asset_only
  LIABILITY_ONLY = :liability_only
  EQUITY_ONLY = :equity_only
  PNL_ONLY = :pnl_only

  # Saldo-dependent rules (bidirectional)
  FLL_STANDARD = :fll_standard        # Forderungen aus L&L
  VLL_STANDARD = :vll_standard        # Verbindlichkeiten aus L&L
  BANK_BIDIRECTIONAL = :bank_bidirectional
  TAX_STANDARD = :tax_standard
  RECEIVABLE_AFFILIATED = :receivable_affiliated  # Forderungen gg. verbundene Unternehmen
  PAYABLE_AFFILIATED = :payable_affiliated        # Verbindlichkeiten gg. verbundene Unternehmen

  # RSID constants for common balance sheet positions
  module Rsids
    # Aktiva
    FORDERUNGEN_LL = "b.aktiva.umlaufvermoegen.forderungen_und_sonstige_vermoegensgegenstaende.forderungen_aus_lieferungen_und_leistungen"
    SONSTIGE_VERMOEGENSGEGENSTAENDE = "b.aktiva.umlaufvermoegen.forderungen_und_sonstige_vermoegensgegenstaende.sonstige_vermoegensgegenstaende"
    FORDERUNGEN_VERBUNDENE = "b.aktiva.umlaufvermoegen.forderungen_und_sonstige_vermoegensgegenstaende.forderungen_gegen_verbundene_unternehmen"
    FORDERUNGEN_BETEILIGUNG = "b.aktiva.umlaufvermoegen.forderungen_und_sonstige_vermoegensgegenstaende.forderungen_gegen_unternehmen_mit_denen_ein_beteiligungsverh"
    LIQUIDE_MITTEL = "b.aktiva.umlaufvermoegen.kassenbestand_bundesbankguthaben_guthaben_bei_kreditinstitut"

    # Passiva
    VERBINDLICHKEITEN_LL = "b.passiva.verbindlichkeiten.verbindlichkeiten_aus_lieferungen_und_leistungen"
    SONSTIGE_VERBINDLICHKEITEN = "b.passiva.verbindlichkeiten.sonstige_verbindlichkeiten_davon_aus_steuern_davon_im_rahmen"
    VERBINDLICHKEITEN_KREDITINSTITUTE = "b.passiva.verbindlichkeiten.verbindlichkeiten_gegenueber_kreditinstituten"
    VERBINDLICHKEITEN_VERBUNDENE = "b.passiva.verbindlichkeiten.verbindlichkeiten_gegenueber_verbundenen_unternehmen"
    VERBINDLICHKEITEN_BETEILIGUNG = "b.passiva.verbindlichkeiten.verbindlichkeiten_gegenueber_unternehmen_mit_denen_ein_betei"
  end

  # Rule definitions
  # Each rule specifies:
  # - name: Human-readable German name
  # - description: What this rule does
  # - debit_rsid: Report Section ID when account has debit balance (nil = use semantic CID as default RSID)
  # - credit_rsid: Report Section ID when account has credit balance (nil = use semantic CID as default RSID)
  # - bidirectional: Whether the account can flip between aktiva and passiva sections
  RULES = {
    asset_only: {
      name: "Nur Aktiva",
      description: "Immer auf der Aktivseite (z.B. Anlagevermögen, Vorräte)",
      debit_rsid: nil,
      credit_rsid: nil,
      bidirectional: false
    },
    liability_only: {
      name: "Nur Passiva",
      description: "Immer auf der Passivseite (z.B. Rückstellungen, Verbindlichkeiten)",
      debit_rsid: nil,
      credit_rsid: nil,
      bidirectional: false
    },
    equity_only: {
      name: "Nur Eigenkapital",
      description: "Immer im Eigenkapital",
      debit_rsid: nil,
      credit_rsid: nil,
      bidirectional: false
    },
    pnl_only: {
      name: "Nur GuV",
      description: "Aufwands- und Ertragskonten - nicht in der Bilanz",
      debit_rsid: nil,
      credit_rsid: nil,
      bidirectional: false
    },
    fll_standard: {
      name: "Forderungen L&L Standard",
      description: "S-Saldo: Forderungen aus L&L | H-Saldo: Sonstige Verbindlichkeiten",
      debit_rsid: Rsids::FORDERUNGEN_LL,
      credit_rsid: Rsids::SONSTIGE_VERBINDLICHKEITEN,
      bidirectional: true
    },
    vll_standard: {
      name: "Verbindlichkeiten L&L Standard",
      description: "H-Saldo: Verbindlichkeiten aus L&L | S-Saldo: Sonstige Vermögensgegenstände",
      debit_rsid: Rsids::SONSTIGE_VERMOEGENSGEGENSTAENDE,
      credit_rsid: Rsids::VERBINDLICHKEITEN_LL,
      bidirectional: true
    },
    bank_bidirectional: {
      name: "Bankkonten bidirektional",
      description: "S-Saldo: Liquide Mittel | H-Saldo: Verbindlichkeiten ggü. Kreditinstituten",
      debit_rsid: Rsids::LIQUIDE_MITTEL,
      credit_rsid: Rsids::VERBINDLICHKEITEN_KREDITINSTITUTE,
      bidirectional: true
    },
    tax_standard: {
      name: "Steuerforderung/-schuld",
      description: "S-Saldo: Sonstige Vermögensgegenstände | H-Saldo: Sonstige Verbindlichkeiten",
      debit_rsid: Rsids::SONSTIGE_VERMOEGENSGEGENSTAENDE,
      credit_rsid: Rsids::SONSTIGE_VERBINDLICHKEITEN,
      bidirectional: true
    },
    receivable_affiliated: {
      name: "Forderungen gg. verbundene Unternehmen",
      description: "S-Saldo: Forderungen gg. verbundene | H-Saldo: Verbindlichkeiten gg. verbundene",
      debit_rsid: Rsids::FORDERUNGEN_VERBUNDENE,
      credit_rsid: Rsids::VERBINDLICHKEITEN_VERBUNDENE,
      bidirectional: true
    },
    payable_affiliated: {
      name: "Verbindlichkeiten gg. verbundene Unternehmen",
      description: "H-Saldo: Verbindlichkeiten gg. verbundene | S-Saldo: Forderungen gg. verbundene",
      debit_rsid: Rsids::FORDERUNGEN_VERBUNDENE,
      credit_rsid: Rsids::VERBINDLICHKEITEN_VERBUNDENE,
      bidirectional: true
    }
  }.freeze


  class << self
    # Get all available rule identifiers
    def all_rules
      RULES.keys
    end

    # Get rule definition by identifier
    def get(rule_id)
      RULES[rule_id&.to_sym]
    end

    # Check if a rule identifier is valid
    def valid?(rule_id)
      RULES.key?(rule_id&.to_sym)
    end

    # Determine the balance sheet Report Section (RSID) for an account based on its balance
    #
    # @param rule_id [Symbol, String] The presentation rule identifier
    # @param total_debit [Float] Total debit amount for the account
    # @param total_credit [Float] Total credit amount for the account
    # @param semantic_cid [String] The semantic category ID (used as default RSID)
    # @return [Hash, nil] { rsid: String, balance: Float, side: :aktiva/:passiva } or nil for P&L
    def apply(rule_id, total_debit, total_credit, semantic_cid)
      rule = RULES[rule_id&.to_sym]

      # Fall back to inferring from semantic_cid if no rule specified
      unless rule
        return apply_default(total_debit, total_credit, semantic_cid)
      end

      # P&L accounts don't appear on balance sheet
      return nil if rule_id&.to_sym == :pnl_only

      net_balance = total_debit - total_credit
      return nil if net_balance.abs < 0.01 # Skip zero balances

      is_debit_balance = net_balance > 0

      if rule[:bidirectional]
        # Saldo-dependent positioning
        if is_debit_balance
          resolved_rsid = rule[:debit_rsid] || semantic_cid
        else
          resolved_rsid = rule[:credit_rsid] || semantic_cid
        end
      else
        # Fixed positioning - always use semantic CID as default RSID
        resolved_rsid = semantic_cid
      end

      side = determine_side(resolved_rsid)

      {
        rsid: resolved_rsid,
        balance: net_balance.abs,
        side: side,
        # Original balance direction (for display purposes)
        debit_balance: is_debit_balance
      }
    end

    # Infer the default rule from account type
    def infer_from_type(account_type)
      case account_type&.to_s
      when "asset"
        :asset_only
      when "liability"
        :liability_only
      when "equity"
        :equity_only
      when "revenue", "expense"
        :pnl_only
      else
        :asset_only
      end
    end

    private

    # Apply default logic when no specific rule is defined.
    # Treats the Semantic Category (CID) as the Report Section ID (RSID).
    def apply_default(total_debit, total_credit, semantic_cid)
      return nil unless semantic_cid

      net_balance = total_debit - total_credit
      return nil if net_balance.abs < 0.01

      side = determine_side(semantic_cid)

      {
        rsid: semantic_cid,
        balance: net_balance.abs,
        side: side,
        debit_balance: net_balance > 0
      }
    end

    # Determine balance sheet side from Report Section ID (RSID)
    def determine_side(rsid)
      return :aktiva unless rsid
      rsid.start_with?("b.aktiva") ? :aktiva : :passiva
    end
  end
end
