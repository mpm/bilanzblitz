# frozen_string_literal: true

module Contrib
  module SKR03Mapping
    module Rules
      # Shared definitions for presentation rules.
      #
      # Centralizes rule patterns and their associated metadata (name, description, RSIDs)
      # to ensure consistency across mapping generation and rule detection.
      module PresentationRuleDefinitions
        # Rule definitions combining detection patterns and reporting metadata
        #
        # NOTE: RSIDs must match the slugified HGB category names.
        # Umlaufvermögen -> umlaufvermoegen
        # Sachanlagen -> sachanlagen
        # Verbindlichkeiten -> verbindlichkeiten
        # Rechnungsabgrenzungsposten -> rechnungsabgrenzungsposten
        RULES = {
          fll_standard: {
            name: "Forderungen L&L Standard",
            description: "S-Saldo: Forderungen aus L&L | H-Saldo: Sonstige Verbindlichkeiten",
            debit_rsid: "b.aktiva.umlaufvermoegen.forderungen_und_sonstige_vermoegensgegenstaende.forderungen_aus_lieferungen_und_leistungen",
            credit_rsid: "b.passiva.verbindlichkeiten.sonstige_verbindlichkeiten_davon_aus_steuern_davon_im_rahmen",
            patterns: [
              /Forderungen.*L.*L.*H-Saldo.*oder.*Verbindlichkeit/i,
              /Forderungen.*Lieferung.*Leistung.*oder.*Verbindlichkeit/i
            ]
          },
          vll_standard: {
            name: "Verbindlichkeiten L&L Standard",
            description: "H-Saldo: Verbindlichkeiten aus L&L | S-Saldo: Sonstige Vermögensgegenstände",
            debit_rsid: "b.aktiva.umlaufvermoegen.forderungen_und_sonstige_vermoegensgegenstaende.sonstige_vermoegensgegenstaende",
            credit_rsid: "b.passiva.verbindlichkeiten.verbindlichkeiten_aus_lieferungen_und_leistungen",
            patterns: [
              /Verbindlichkeit.*L.*L.*S-Saldo.*oder.*Vermögensgegenst/i,
              /Verbindlichkeit.*Lieferung.*Leistung.*oder.*Vermögensgegenst/i,
              /Verbindlichkeit.*Lieferung.*Leistung.*oder.*Forderung/i
            ]
          },
          bank_bidirectional: {
            name: "Bankkonten bidirektional",
            description: "S-Saldo: Liquide Mittel | H-Saldo: Verbindlichkeiten ggü. Kreditinstituten",
            debit_rsid: "b.aktiva.umlaufvermoegen.kassenbestand_bundesbankguthaben_guthaben_bei_kreditinstitut",
            credit_rsid: "b.passiva.verbindlichkeiten.verbindlichkeiten_gegenueber_kreditinstituten",
            patterns: [
              /Kassenbestand.*oder.*Verbindlichkeit.*Kreditinstitut/i,
              /Guthaben.*Kreditinstitut.*oder.*Verbindlichkeit/i,
              /Bank.*oder.*Verbindlichkeit.*Kreditinstitut/i
            ]
          },
          tax_standard: {
            name: "Steuerforderung/-schuld",
            description: "S-Saldo: Sonstige Vermögensgegenstände | H-Saldo: Sonstige Verbindlichkeiten",
            debit_rsid: "b.aktiva.umlaufvermoegen.forderungen_und_sonstige_vermoegensgegenstaende.sonstige_vermoegensgegenstaende",
            credit_rsid: "b.passiva.verbindlichkeiten.sonstige_verbindlichkeiten_davon_aus_steuern_davon_im_rahmen",
            patterns: [
              /Steuer.*oder.*Steuer/i,
              /Steuerforderung.*oder.*Steuerverbindlichkeit/i
            ]
          },
          receivable_affiliated: {
            name: "Forderungen gg. verbundene Unternehmen",
            description: "S-Saldo: Forderungen gg. verbundene | H-Saldo: Verbindlichkeiten gg. verbundene",
            debit_rsid: "b.aktiva.umlaufvermoegen.forderungen_und_sonstige_vermoegensgegenstaende.forderungen_gegen_verbundene_unternehmen",
            credit_rsid: "b.passiva.verbindlichkeiten.verbindlichkeiten_gegenueber_verbundenen_unternehmen",
            patterns: [
              /Forderung.*verbunden.*Unternehmen.*oder.*Verbindlichkeit.*verbunden/i,
              /Forderung.*verbund.*oder.*Verbindlichkeit.*verbund/i
            ]
          },
          payable_affiliated: {
            name: "Verbindlichkeiten gg. verbundene Unternehmen",
            description: "H-Saldo: Verbindlichkeiten gg. verbundene | S-Saldo: Forderungen gg. verbundene",
            debit_rsid: "b.aktiva.umlaufvermoegen.forderungen_und_sonstige_vermoegensgegenstaende.forderungen_gegen_verbundene_unternehmen",
            credit_rsid: "b.passiva.verbindlichkeiten.verbindlichkeiten_gegenueber_verbundenen_unternehmen",
            patterns: [
              /Verbindlichkeit.*verbunden.*Unternehmen.*oder.*Forderung.*verbunden/i,
              /Verbindlichkeit.*verbund.*oder.*Forderung.*verbund/i
            ]
          },
          receivable_beteiligung: {
            name: "Forderungen gg. Beteiligungsunternehmen",
            description: "S-Saldo: Forderungen gg. Beteiligung | H-Saldo: Verbindlichkeiten gg. Beteiligung",
            debit_rsid: "b.aktiva.umlaufvermoegen.forderungen_und_sonstige_vermoegensgegenstaende.forderungen_gegen_unternehmen_mit_denen_ein_beteiligungsverhaeltnis_besteht",
            credit_rsid: "b.passiva.verbindlichkeiten.verbindlichkeiten_gegenueber_unternehmen_mit_denen_ein_beteiligungsverhaeltnis_besteht",
            patterns: [
              /Forderung.*Beteiligung.*oder.*Verbindlichkeit.*Beteiligung/i
            ]
          },
          payable_beteiligung: {
            name: "Verbindlichkeiten gg. Beteiligungsunternehmen",
            description: "H-Saldo: Verbindlichkeiten gg. Beteiligung | S-Saldo: Forderungen gg. Beteiligung",
            debit_rsid: "b.aktiva.umlaufvermoegen.forderungen_und_sonstige_vermoegensgegenstaende.forderungen_gegen_unternehmen_mit_denen_ein_beteiligungsverhaeltnis_besteht",
            credit_rsid: "b.passiva.verbindlichkeiten.verbindlichkeiten_gegenueber_unternehmen_mit_denen_ein_beteiligungsverhaeltnis_besteht",
            patterns: [
              /Verbindlichkeit.*Beteiligung.*oder.*Forderung.*Beteiligung/i
            ]
          },
          sonstige_bidirectional: {
            name: "Sonstige Forderungen/Verbindlichkeiten bidirektional",
            description: "S-Saldo: Sonstige Vermögensgegenstände | H-Saldo: Sonstige Verbindlichkeiten",
            debit_rsid: "b.aktiva.umlaufvermoegen.forderungen_und_sonstige_vermoegensgegenstaende.sonstige_vermoegensgegenstaende",
            credit_rsid: "b.passiva.verbindlichkeiten.sonstige_verbindlichkeiten_davon_aus_steuern_davon_im_rahmen",
            patterns: [
              /Sonstige Vermögensgegenstände.*oder.*sonstige Verbindlichkeit/i,
              /Sonstige Vermögensgegenst.*oder.*Verbindlichkeit/i
            ]
          },
          asset_only: {
            name: "Nur Aktiva",
            description: "Immer auf der Aktivseite (z.B. Anlagevermögen, Vorräte)",
            debit_rsid: nil,
            credit_rsid: nil,
            patterns: []
          },
          liability_only: {
            name: "Nur Passiva",
            description: "Immer auf der Passivseite (z.B. Rückstellungen, Verbindlichkeiten)",
            debit_rsid: nil,
            credit_rsid: nil,
            patterns: []
          },
          equity_only: {
            name: "Nur Eigenkapital",
            description: "Immer im Eigenkapital",
            debit_rsid: nil,
            credit_rsid: nil,
            patterns: []
          },
          pnl_only: {
            name: "Nur GuV",
            description: "Aufwands- und Ertragskonten - nicht in der Bilanz",
            debit_rsid: nil,
            credit_rsid: nil,
            patterns: []
          }
        }.freeze
      end
    end
  end
end
