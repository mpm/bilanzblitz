# Service to centralize tax form field definitions and mappings
# Similar to AccountMap, this service uses frozen hashes to define
# field configurations for different tax report types
class TaxFormFieldMap
  class << self
    # UStVA (Umsatzsteuervoranmeldung) field definitions
    # Core fields only: output VAT, input VAT, reverse charge, net liability
    USTVA_FIELDS = {
      # Output VAT fields (Umsatzsteuer)
      kz_81: {
        field_number: 81,
        name: "Umsatzsteuer 19%",
        description: "Umsatzsteuer aus Lieferungen und Leistungen zum Steuersatz von 19%",
        accounts: [ Account::VAT_ACCOUNTS[:output_19] ],
        calculation_type: :account_balance,
        section: :output_vat,
        display_order: 1
      },
      kz_86: {
        field_number: 86,
        name: "Umsatzsteuer 7%",
        description: "Umsatzsteuer aus Lieferungen und Leistungen zum Steuersatz von 7%",
        accounts: [ Account::VAT_ACCOUNTS[:output_7] ],
        calculation_type: :account_balance,
        section: :output_vat,
        display_order: 2
      },

      # Input VAT fields (Vorsteuer)
      kz_66: {
        field_number: 66,
        name: "Vorsteuer 19%",
        description: "Abziehbare Vorsteuer aus Rechnungen anderer Unternehmer (19%)",
        accounts: [ Account::VAT_ACCOUNTS[:input_19] ],
        calculation_type: :account_balance,
        section: :input_vat,
        display_order: 3
      },
      kz_61: {
        field_number: 61,
        name: "Vorsteuer 7%",
        description: "Abziehbare Vorsteuer aus Rechnungen anderer Unternehmer (7%)",
        accounts: [ Account::VAT_ACCOUNTS[:input_7] ],
        calculation_type: :account_balance,
        section: :input_vat,
        display_order: 4
      },

      # Reverse charge fields
      kz_46: {
        field_number: 46,
        name: "Reverse Charge (Ausgangsumsatz)",
        description: "Steuerschuldner ist der Leistungsempfänger (§ 13b UStG) - Ausgangsumsatz",
        accounts: [ Account::VAT_ACCOUNTS[:reverse_charge_output_19] ],
        calculation_type: :account_balance,
        section: :reverse_charge,
        display_order: 5
      },
      kz_47: {
        field_number: 47,
        name: "Reverse Charge (Vorsteuer)",
        description: "Abziehbare Vorsteuer bei Reverse Charge (§ 13b UStG)",
        accounts: [ Account::VAT_ACCOUNTS[:reverse_charge_input_19] ],
        calculation_type: :account_balance,
        section: :reverse_charge,
        display_order: 6
      },

      # Calculated net VAT liability
      kz_83: {
        field_number: 83,
        name: "Verbleibende Umsatzsteuer",
        description: "Umsatzsteuer-Vorauszahlung (Zahllast) bzw. Überschuss (Erstattung)",
        calculation_type: :formula,
        formula: :calculate_net_vat_liability,
        section: :summary,
        display_order: 7
      }
    }.freeze

    # Körperschaftsteuer (KSt) field definitions
    # Base fields from GuV/Balance Sheet + editable adjustments
    KST_FIELDS = {
      # Base data from GuV
      einkommen: {
        name: "Jahresüberschuss/Jahresfehlbetrag",
        description: "Gewinn oder Verlust laut GuV (§ 275 HGB)",
        source: :net_income,
        section: :base_data,
        editable: false,
        display_order: 1
      },

      # Adjustments (außerbilanzielle Korrekturen)
      nicht_abzugsfaehige_aufwendungen: {
        name: "Nicht abzugsfähige Aufwendungen",
        description: "Betriebsausgaben, die steuerlich nicht abziehbar sind (z.B. Bewirtungskosten über 70%, Geldbußen)",
        section: :adjustments,
        editable: true,
        default_value: 0.0,
        adjustment_sign: :add,
        display_order: 2
      },
      steuerfreie_ertraege: {
        name: "Steuerfreie Erträge",
        description: "Betriebliche Erträge, die steuerfrei sind",
        section: :adjustments,
        editable: true,
        default_value: 0.0,
        adjustment_sign: :subtract,
        display_order: 3
      },
      verlustvortrag: {
        name: "Verlustvortrag aus Vorjahren",
        description: "Verrechnung von Verlusten aus früheren Jahren",
        section: :adjustments,
        editable: true,
        default_value: 0.0,
        adjustment_sign: :subtract,
        display_order: 4
      },
      spenden: {
        name: "Spenden und Mitgliedsbeiträge",
        description: "Abzugsfähige Spenden und Mitgliedsbeiträge",
        section: :adjustments,
        editable: true,
        default_value: 0.0,
        adjustment_sign: :subtract,
        display_order: 5
      },
      sonderabzuege: {
        name: "Sonstige Sonderabzüge",
        description: "Weitere steuerliche Abzüge",
        section: :adjustments,
        editable: true,
        default_value: 0.0,
        adjustment_sign: :subtract,
        display_order: 6
      },

      # Calculated fields
      einkommen_vor_steuer: {
        name: "Zu versteuerndes Einkommen",
        description: "Jahresüberschuss nach außerbilanziellen Korrekturen",
        calculation_type: :formula,
        formula: :calculate_taxable_income,
        section: :calculated,
        editable: false,
        display_order: 7
      },
      koerperschaftsteuer: {
        name: "Körperschaftsteuer (15%)",
        description: "Festzusetzende Körperschaftsteuer",
        calculation_type: :formula,
        formula: :calculate_kst,
        section: :calculated,
        editable: false,
        display_order: 8
      }
    }.freeze

    def ustva_fields
      USTVA_FIELDS
    end

    # UStVA field lookup
    def ustva_field(field_key)
      validate_ustva_field!(field_key)
      USTVA_FIELDS[field_key]
    end

    # KSt field lookup
    def kst_field(field_key)
      validate_kst_field!(field_key)
      KST_FIELDS[field_key]
    end

    # Get all UStVA fields in display order
    def ustva_fields_ordered
      USTVA_FIELDS.values.sort_by { |f| f[:display_order] }
    end

    # Get UStVA fields grouped by section
    def ustva_fields_by_section
      {
        output_vat: fields_for_section(USTVA_FIELDS, :output_vat),
        input_vat: fields_for_section(USTVA_FIELDS, :input_vat),
        reverse_charge: fields_for_section(USTVA_FIELDS, :reverse_charge),
        summary: fields_for_section(USTVA_FIELDS, :summary)
      }
    end

    # Get KSt fields grouped by section
    def kst_fields_by_section
      {
        base_data: fields_for_section(KST_FIELDS, :base_data),
        adjustments: fields_for_section(KST_FIELDS, :adjustments),
        calculated: fields_for_section(KST_FIELDS, :calculated)
      }
    end

    # Get all editable KSt fields
    def kst_editable_fields
      KST_FIELDS.select { |_key, field| field[:editable] == true }
    end

    # Section labels for UStVA
    def ustva_section_label(section_key)
      case section_key
      when :output_vat then "Umsatzsteuer (Output VAT)"
      when :input_vat then "Abziehbare Vorsteuer (Input VAT)"
      when :reverse_charge then "Reverse Charge (§ 13b UStG)"
      when :summary then "Zusammenfassung"
      else
        raise ArgumentError, "Unknown UStVA section: #{section_key}"
      end
    end

    # Section labels for KSt
    def kst_section_label(section_key)
      case section_key
      when :base_data then "Ausgangswerte"
      when :adjustments then "Außerbilanzielle Korrekturen"
      when :calculated then "Berechnete Werte"
      else
        raise ArgumentError, "Unknown KSt section: #{section_key}"
      end
    end

    private

    def validate_ustva_field!(field_key)
      unless USTVA_FIELDS.key?(field_key)
        raise ArgumentError, "Unknown UStVA field: #{field_key}. Available fields: #{USTVA_FIELDS.keys.join(', ')}"
      end
    end

    def validate_kst_field!(field_key)
      unless KST_FIELDS.key?(field_key)
        raise ArgumentError, "Unknown KSt field: #{field_key}. Available fields: #{KST_FIELDS.keys.join(', ')}"
      end
    end

    def fields_for_section(fields_hash, section)
      fields_hash.select { |_key, field| field[:section] == section }
                 .sort_by { |_key, field| field[:display_order] }
                 .to_h
    end
  end
end
