# Service to map accounts to GuV sections and balance sheet categories
# Provides centralized configuration for account categorization according to § 275 Abs. 2 HGB
class AccountMap
  # Define GuV sections according to § 275 Abs. 2 HGB (Gesamtkostenverfahren)
  GUV_SECTIONS = {
    umsatzerloese: {
      title: "1. Umsatzerlöse",
      accounts: []
    },
    bestandsveraenderungen: {
      title: "2. Erhöhung oder Verminderung des Bestands an fertigen und unfertigen Erzeugnissen",
      accounts: []
    },
    aktivierte_eigenleistungen: {
      title: "3. Andere aktivierte Eigenleistungen",
      accounts: []
    },
    sonstige_betriebliche_ertraege: {
      title: "4. Sonstige betriebliche Erträge",
      accounts: []
    },
    materialaufwand_roh_hilfs_betriebsstoffe: {
      title: "5a. Aufwendungen für Roh-, Hilfs- und Betriebsstoffe und für bezogene Waren",
      accounts: [ "5000-5999" ]
    },
    materialaufwand_bezogene_leistungen: {
      title: "5b. Aufwendungen für bezogene Leistungen",
      accounts: []
    },
    personalaufwand_loehne_gehaelter: {
      title: "6a. Löhne und Gehälter",
      accounts: [ "6000-6999" ]
    },
    personalaufwand_soziale_abgaben: {
      title: "6b. Soziale Abgaben und Aufwendungen für Altersversorgung und für Unterstützung",
      accounts: []
    },
    abschreibungen_anlagevermoegen: {
      title: "7a. Abschreibungen auf immaterielle Vermögensgegenstände des Anlagevermögens und Sachanlagen",
      accounts: [ "7600-7699" ]
    },
    abschreibungen_umlaufvermoegen: {
      title: "7b. Abschreibungen auf Vermögensgegenstände des Umlaufvermögens",
      accounts: []
    },
    sonstige_betriebliche_aufwendungen: {
      title: "8. Sonstige betriebliche Aufwendungen",
      accounts: [ "4000-4999" ]
    },
    ertraege_beteiligungen: {
      title: "9. Erträge aus Beteiligungen",
      accounts: []
    },
    ertraege_wertpapiere: {
      title: "10. Erträge aus anderen Wertpapieren und Ausleihungen des Finanzanlagevermögens",
      accounts: []
    },
    sonstige_zinsen_ertraege: {
      title: "11. Sonstige Zinsen und ähnliche Erträge",
      accounts: []
    },
    abschreibungen_finanzanlagen: {
      title: "12. Abschreibungen auf Finanzanlagen und auf Wertpapiere des Umlaufvermögens",
      accounts: []
    },
    zinsen_aufwendungen: {
      title: "13. Zinsen und ähnliche Aufwendungen",
      accounts: []
    },
    steuern_einkommen_ertrag: {
      title: "14. Steuern vom Einkommen und vom Ertrag",
      accounts: []
    },
    sonstige_steuern: {
      title: "16. Sonstige Steuern",
      accounts: []
    }
  }.freeze

  # Balance sheet categories (stub for future implementation)
  BALANCE_SHEET_CATEGORIES = {
    anlagevermoegen: {
      title: "Anlagevermögen",
      accounts: [ "0000-0999" ]
    },
    umlaufvermoegen: {
      title: "Umlaufvermögen",
      accounts: [ "1000-1999" ]
    },
    eigenkapital: {
      title: "Eigenkapital",
      accounts: [ "2000-2999" ]
    },
    fremdkapital: {
      title: "Fremdkapital",
      accounts: [ "3000-3999" ]
    }
  }.freeze

  class << self
    # Get the human-readable title for a GuV section
    # @param section_id [Symbol] The section identifier (e.g., :umsatzerloese)
    # @return [String] The section title
    # @raise [ArgumentError] if section_id is unknown
    def section_title(section_id)
      validate_guv_section!(section_id)
      GUV_SECTIONS[section_id][:title]
    end

    # Get the full list of account codes for a GuV section (expands ranges)
    # @param section_id [Symbol] The section identifier
    # @return [Array<String>] Array of account codes
    # @raise [ArgumentError] if section_id is unknown
    def account_codes(section_id)
      validate_guv_section!(section_id)
      expand_account_ranges(GUV_SECTIONS[section_id][:accounts])
    end

    # Filter accounts list to only include those matching the given section
    # @param account_list [Array<Hash>] List of account hashes with :code key
    # @param section_id [Symbol] The section identifier
    # @return [Array<Hash>] Filtered list of accounts
    # @raise [ArgumentError] if section_id is unknown
    def find_accounts(account_list, section_id)
      validate_guv_section!(section_id)
      section_codes = account_codes(section_id)

      # If section has no configured accounts, return empty array
      return [] if section_codes.empty?

      # Filter accounts whose code matches the section
      account_list.select do |account|
        section_codes.include?(account[:code])
      end
    end

    # Get balance sheet category title (stub for future implementation)
    # @param category_id [Symbol] The category identifier
    # @return [String] The category title
    # @raise [ArgumentError] if category_id is unknown
    def balance_sheet_category_title(category_id)
      validate_balance_sheet_category!(category_id)
      BALANCE_SHEET_CATEGORIES[category_id][:title]
    end

    # Get account codes for balance sheet category (stub for future implementation)
    # @param category_id [Symbol] The category identifier
    # @return [Array<String>] Array of account codes
    # @raise [ArgumentError] if category_id is unknown
    def balance_sheet_account_codes(category_id)
      validate_balance_sheet_category!(category_id)
      expand_account_ranges(BALANCE_SHEET_CATEGORIES[category_id][:accounts])
    end

    # Filter accounts by balance sheet category (stub for future implementation)
    # @param account_list [Array<Hash>] List of account hashes with :code key
    # @param category_id [Symbol] The category identifier
    # @return [Array<Hash>] Filtered list of accounts
    # @raise [ArgumentError] if category_id is unknown
    def find_balance_sheet_accounts(account_list, category_id)
      validate_balance_sheet_category!(category_id)
      category_codes = balance_sheet_account_codes(category_id)

      return [] if category_codes.empty?

      account_list.select do |account|
        category_codes.include?(account[:code])
      end
    end

    private

    # Validate that the section_id exists in GUV_SECTIONS
    def validate_guv_section!(section_id)
      unless GUV_SECTIONS.key?(section_id)
        raise ArgumentError, "Unknown GuV section: #{section_id}. Valid sections: #{GUV_SECTIONS.keys.join(', ')}"
      end
    end

    # Validate that the category_id exists in BALANCE_SHEET_CATEGORIES
    def validate_balance_sheet_category!(category_id)
      unless BALANCE_SHEET_CATEGORIES.key?(category_id)
        raise ArgumentError, "Unknown balance sheet category: #{category_id}. Valid categories: #{BALANCE_SHEET_CATEGORIES.keys.join(', ')}"
      end
    end

    # Expand account ranges into individual account codes
    # @param account_specs [Array<String>] Array of individual codes or ranges (e.g., ["4000", "5000-5999"])
    # @return [Array<String>] Array of individual account codes
    def expand_account_ranges(account_specs)
      result = []

      account_specs.each do |spec|
        if spec.include?("-")
          # It's a range like "4000-4999"
          start_code, end_code = spec.split("-")
          start_num = start_code.to_i
          end_num = end_code.to_i

          (start_num..end_num).each do |num|
            result << num.to_s.rjust(start_code.length, "0")
          end
        else
          # It's an individual account code
          result << spec
        end
      end

      result.uniq.sort
    end
  end
end
