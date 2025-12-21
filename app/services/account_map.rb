# Service to map accounts to GuV report sections and balance sheet semantic categories.
# Provides centralized configuration for account categorization according to § 275 Abs. 2 HGB.
class AccountMap
  # Define GuV report sections according to § 275 Abs. 2 HGB (Gesamtkostenverfahren)
  GUV_SECTIONS = {
    umsatzerloese: {
      title: "1. Umsatzerlöse",
      accounts: [ "2750-2753", "2764", "8000", "8100", "8105", "8110", "8120", "8125", "8128", "8135", "8140", "8150", "8160", "8165", "8190-8197", "8200", "8290", "8300", "8310", "8315", "8320", "8330-8340", "8400", "8410", "8420", "8449", "8499", "8510-8511", "8514-8516", "8519-8520", "8540", "8570-8571", "8574-8577", "8579-8582", "8589", "8607", "8700-8706", "8710-8712", "8719-8722", "8724-8728", "8730-8732", "8734-8738", "8741-8750", "8752", "8760", "8762", "8769-8770", "8780", "8782", "8790", "8792", "8950", "8955", "8959" ]
    },
    bestandsveraenderungen: {
      title: "2. Erhöhung oder Verminderung des Bestands an fertigen und unfertigen Erzeugnissen",
      accounts: []
    },
    aktivierte_eigenleistungen: {
      title: "3. Andere aktivierte Eigenleistungen",
      accounts: [ "8990", "8994-8995" ]
    },
    sonstige_betriebliche_ertraege: {
      title: "4. Sonstige betriebliche Erträge",
      accounts: [ "2315-2318", "2504", "2510", "2520", "2590", "2594", "2660-2661", "2666", "2700", "2705", "2707", "2709-2716", "2724-2732", "2735-2737", "2740-2744", "2746-2747", "2749", "2760", "2762", "8590-8591", "8595-8596", "8603-8606", "8609-8614", "8625", "8630", "8635", "8640", "8645", "8649", "8820", "8826", "8828-8829", "8837-8839", "8850-8853", "8900", "8905-8906", "8908", "8910", "8913", "8915", "8917-8925", "8928-8935", "8938-8940", "8944-8945", "8947-8949" ]
    },
    materialaufwand_roh_hilfs_betriebsstoffe: {
      title: "5a. Aufwendungen für Roh-, Hilfs- und Betriebsstoffe und für bezogene Waren",
      accounts: [ "3000", "3010", "3020", "3029-3030", "3040", "3060-3062", "3064", "3066-3068", "3070-3072", "3075-3077", "3089-3093", "3300", "3310", "3347-3349", "3400", "3410", "3418-3420", "3425", "3430-3431", "3435-3436", "3440-3441", "3500", "3505", "3510", "3540", "3550-3554", "3558-3561", "3565-3566", "3600", "3610", "3620", "3650", "3660", "3700-3701", "3710", "3712", "3714-3718", "3720", "3722", "3724-3726", "3730-3750", "3752-3756", "3760", "3762", "3769-3770", "3780", "3782-3788", "3790", "3792-3796", "3798-3800", "3830", "3850", "3950", "3955", "3960", "3990", "4000" ]
    },
    materialaufwand_bezogene_leistungen: {
      title: "5b. Aufwendungen für bezogene Leistungen",
      accounts: [ "3106-3111", "3113-3116", "3120", "3122-3125", "3127", "3130-3131", "3133-3136", "3140", "3142-3145", "3147", "3150-3155", "3160", "3165", "3170", "3175", "3180", "3185" ]
    },
    personalaufwand_loehne_gehaelter: {
      title: "6a. Löhne und Gehälter",
      accounts: [ "4100", "4110", "4120", "4124-4129", "4145-4159", "4170", "4175", "4180", "4190", "4194-4199" ]
    },
    personalaufwand_soziale_abgaben: {
      title: "6b. Soziale Abgaben und Aufwendungen für Altersversorgung und für Unterstützung",
      accounts: [ "4130", "4137-4138", "4140-4141", "4144", "4160", "4165-4169" ]
    },
    abschreibungen_anlagevermoegen: {
      title: "7a. Abschreibungen auf immaterielle Vermögensgegenstände des Anlagevermögens und Sachanlagen",
      accounts: [ "2430-2431", "2436", "2440-2441", "4880", "4882", "4892-4893" ]
    },
    abschreibungen_umlaufvermoegen: {
      title: "7b. Abschreibungen auf Vermögensgegenstände des Umlaufvermögens",
      accounts: []
    },
    sonstige_betriebliche_aufwendungen: {
      title: "8. Sonstige betriebliche Aufwendungen",
      accounts: [ "2004", "2007", "2010", "2020", "2090-2091", "2094", "2150-2151", "2166", "2170-2171", "2176", "2300", "2307-2313", "2324-2328", "2339", "2342-2345", "2347", "2350", "2380-2387", "2389-2390", "2400-2403", "2406", "2408", "2450-2451", "2890-2895", "4139", "4200", "4210-4212", "4215", "4219-4220", "4222", "4228-4230", "4240", "4250", "4260", "4270", "4280", "4287-4290", "4300-4301", "4304", "4360", "4366", "4370", "4380", "4390", "4396-4397", "4400", "4500", "4520", "4530", "4540", "4550", "4560", "4570", "4575", "4580", "4590", "4595", "4600", "4605", "4630-4632", "4635-4640", "4650-4655", "4660", "4663-4664", "4666", "4668", "4670", "4672-4674", "4676", "4678-4681", "4700", "4710", "4730", "4750", "4760", "4790", "4800-4801", "4805-4806", "4808-4810", "4886-4887", "4900", "4902", "4905", "4909-4910", "4920", "4925", "4930", "4940", "4945-4946", "4948-4950", "4955", "4957-4961", "4963-4965", "4969-4971", "4975-4977", "4980", "4985", "4990-5000", "5999-6000", "6999", "8800-8801", "8807-8809", "8818-8819" ]
    },
    ertraege_beteiligungen: {
      title: "9. Erträge aus Beteiligungen",
      accounts: [ "2600", "2603", "2613-2616", "2618-2619" ]
    },
    ertraege_wertpapiere: {
      title: "10. Erträge aus anderen Wertpapieren und Ausleihungen des Finanzanlagevermögens",
      accounts: [ "2620-2623", "2625-2626", "2640-2641", "2646-2649" ]
    },
    sonstige_zinsen_ertraege: {
      title: "11. Sonstige Zinsen und ähnliche Erträge",
      accounts: [ "2650", "2654-2659", "2680", "2682-2685", "2689", "8650", "8660" ]
    },
    abschreibungen_finanzanlagen: {
      title: "12. Abschreibungen auf Finanzanlagen und auf Wertpapiere des Umlaufvermögens",
      accounts: [ "4866", "4870-4878" ]
    },
    zinsen_aufwendungen: {
      title: "13. Zinsen und ähnliche Aufwendungen",
      accounts: [ "2100", "2102-2105", "2107-2111", "2113-2120", "2123-2129", "2140-2145", "2148-2149" ]
    },
    steuern_einkommen_ertrag: {
      title: "14. Steuern vom Einkommen und vom Ertrag",
      accounts: []
    },
    sonstige_steuern: {
      title: "16. Sonstige Steuern",
      accounts: [ "2285", "2287", "2289", "2375", "4340", "4350", "4355", "4510" ]
    }
  }.freeze

  # Revenue sections in GuV (for account type classification)
  REVENUE_SECTIONS = [
    :umsatzerloese,
    :bestandsveraenderungen,
    :aktivierte_eigenleistungen,
    :sonstige_betriebliche_ertraege,
    :ertraege_beteiligungen,
    :ertraege_wertpapiere,
    :sonstige_zinsen_ertraege
  ].freeze

  # Expense sections in GuV (for account type classification)
  EXPENSE_SECTIONS = [
    :materialaufwand_roh_hilfs_betriebsstoffe,
    :materialaufwand_bezogene_leistungen,
    :personalaufwand_loehne_gehaelter,
    :personalaufwand_soziale_abgaben,
    :abschreibungen_anlagevermoegen,
    :abschreibungen_umlaufvermoegen,
    :sonstige_betriebliche_aufwendungen,
    :abschreibungen_finanzanlagen,
    :zinsen_aufwendungen,
    :steuern_einkommen_ertrag,
    :sonstige_steuern
  ].freeze

  class << self
    # Load balance sheet structure from JSON file
    # @return [Hash] Raw JSON structure from bilanz-sections-mapping.json
    def load_balance_sheet_structure
      @balance_sheet_structure ||= begin
        path = Rails.root.join("contrib", "bilanz-sections-mapping.json")
        JSON.parse(File.read(path), symbolize_names: true)
      end
    end

    # Get nested balance sheet categories (dynamically loaded from JSON)
    # @return [Hash] Transformed nested structure compatible with existing code
    def nested_balance_sheet_categories
      @nested_categories ||= transform_json_to_nested_structure(load_balance_sheet_structure)
    end

    # Get the human-readable title for a GuV report section
    # @param section_id [Symbol] The section identifier (e.g., :umsatzerloese)
    # @return [String] The section title
    # @raise [ArgumentError] if section_id is unknown
    def section_title(section_id)
      validate_guv_section!(section_id)
      GUV_SECTIONS[section_id][:title]
    end

    # Get the full list of account codes for a GuV report section (expands ranges)
    # @param section_id [Symbol] The section identifier
    # @return [Array<String>] Array of account codes
    # @raise [ArgumentError] if section_id is unknown
    def account_codes(section_id)
      validate_guv_section!(section_id)
      expand_account_ranges(GUV_SECTIONS[section_id][:accounts])
    end

    # Filter accounts list to only include those matching the given report section
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

    # Get nested category structure for a top-level category
    # @param category_id [Symbol] The top-level category (:anlagevermoegen, :umlaufvermoegen, etc.)
    # @return [Hash] Nested structure with name, codes, children
    # @raise [ArgumentError] if category_id is not a valid top-level category
    def nested_category_structure(category_id)
      validate_nested_category!(category_id)

      # Search in aktiva
      if nested_balance_sheet_categories[:aktiva].key?(category_id)
        return nested_balance_sheet_categories[:aktiva][category_id]
      end

      # Search in passiva
      if nested_balance_sheet_categories[:passiva].key?(category_id)
        return nested_balance_sheet_categories[:passiva][category_id]
      end

      raise ArgumentError, "Category #{category_id} not found in nested structure"
    end

    # Get the official German name for any category (works with nested categories)
    # @param category_id [Symbol] Any category identifier
    # @return [String, nil] The German name or nil if not found
    def category_name(category_id)
      # Search nested structure
      found = find_in_nested_structure(category_id)
      found ? found[:name] : nil
    end

    # Get all account codes for a category (works with nested categories, flattens all children)
    # @param category_id [Symbol] Any category identifier
    # @return [Array<String>] Array of account codes
    def nested_account_codes(category_id)
      found = find_in_nested_structure(category_id)
      return [] unless found

      collect_all_codes(found)
    end

    # Build a BalanceSheetSection tree for a top-level category
    # @param account_list [Array<Hash>] List of account hashes with :code, :name, :balance keys
    # @param category_id [Symbol] The top-level category identifier
    # @return [BalanceSheetSection] The root section with nested children
    def build_nested_section(account_list, category_id)
      structure = nested_category_structure(category_id)
      build_section_recursive(account_list, category_id, structure, level: 1)
    end

    # Determine account type (asset, liability, equity, expense, revenue) for a given account code.
    # The account type is derived from the account's Semantic Category.
    # @param account_code [String] The account code (e.g., "0750", "4000")
    # @return [String, nil] The account type or nil if not found in any category
    def account_type_for_code(account_code)
      # 1. Check if special handling applies (deferred - always returns nil for now)
      special_type = check_special_category_handling(account_code)
      return special_type if special_type

      # 2. Check balance sheet categories (nested structure)
      balance_result = find_account_in_nested_structure(account_code)
      if balance_result
        return account_type_from_balance_position(
          balance_result[:side],
          balance_result[:top_level_category]
        )
      end

      # 3. Check GuV sections
      guv_section = find_guv_section_for_account(account_code)
      if guv_section
        return REVENUE_SECTIONS.include?(guv_section) ? "revenue" : "expense"
      end

      # 4. Not found in any category
      nil
    end

    # Get the hierarchical category ID (cid) for an account code.
    # The cid acts as the logical identity and the default Report Section ID (RSID).
    # @param account_code [String] The account code (e.g., "0750", "1400")
    # @return [String, nil] The full cid path (e.g., "b.aktiva.anlagevermoegen.sachanlagen") or nil
    def cid_for_code(account_code)
      # Search balance sheet (aktiva and passiva)
      [ :aktiva, :passiva ].each do |side|
        nested_balance_sheet_categories[side].each_value do |top_data|
          result = find_cid_in_category(account_code, top_data)
          return result if result
        end
      end

      # Search GuV
      guv_section = find_guv_section_for_account(account_code)
      return "guv.#{guv_section}" if guv_section

      nil
    end

    private

    # Recursively search for account code and return full cid path (using the rsid field)
    # @param account_code [String] The account code to search for
    # @param category_data [Hash] Category data with :codes, :children and :rsid
    # @param cid_path [String] (Not used anymore, kept for signature consistency if needed)
    # @return [String, nil] Full cid path if found, nil otherwise
    def find_cid_in_category(account_code, category_data, cid_path = nil)
      # Check codes at this level
      codes = expand_account_ranges(category_data[:codes] || [])
      return category_data[:rsid] if codes.include?(account_code)

      # Recursively check children
      if category_data[:children]
        category_data[:children].each_value do |child_data|
          result = find_cid_in_category(account_code, child_data)
          return result if result
        end
      end

      nil
    end

    # Transform JSON structure to nested hash format
    # @param json_data [Hash] Raw JSON data with :aktiva and :passiva keys
    # @return [Hash] Transformed structure compatible with existing code
    def transform_json_to_nested_structure(json_data)
      {
        aktiva: transform_section_hash(json_data[:aktiva]),
        passiva: transform_section_hash(json_data[:passiva])
      }
    end

    # Transform a section hash (aktiva or passiva)
    # @param section_data [Hash] Section data from JSON
    # @return [Hash] Transformed section with category keys
    def transform_section_hash(section_data)
      result = {}
      section_data.each do |name, data|
        key = name_to_key(name)
        result[key] = transform_category(name, data)
      end
      result
    end

    # Transform a single category from JSON format to internal format
    # @param name [String, Symbol] Category name
    # @param data [Hash] Category data with :codes, :items, :children
    # @return [Hash] Transformed category with :name, :codes, :children
    def transform_category(name, data)
      # Convert to string if it's a symbol (from JSON.parse with symbolize_names: true)
      name_str = name.to_s

      # Ensure codes is always an array (handle empty strings from JSON)
      codes = data[:codes]
      codes = [] unless codes.is_a?(Array)

      category = {
        name: name_str,
        codes: codes,
        children: {},
        rsid: data[:rsid] # Preserve the RSID from JSON
      }

      # Handle 'items' array (used for top-level categories like Anlagevermögen)
      if data[:items]
        data[:items].each do |item|
          # Some items have only children without a name (e.g., Rückstellungen)
          if item[:name]
            item_key = name_to_key(item[:name])
            category[:children][item_key] = {
              name: item[:name],
              codes: ensure_codes_array(item[:codes]),
              children: {},
              rsid: item[:rsid]
            }

            # Handle 'children' within items
            if item[:children]
              item[:children].each do |child|
                child_key = name_to_key(child[:name])
                category[:children][item_key][:children][child_key] = {
                  name: child[:name],
                  codes: ensure_codes_array(child[:codes]),
                  children: {},
                  rsid: child[:rsid]
                }
              end
            end
          elsif item[:children]
            # Item has no name, add children directly to category
            item[:children].each do |child|
              child_key = name_to_key(child[:name])
              category[:children][child_key] = {
                name: child[:name],
                codes: ensure_codes_array(child[:codes]),
                children: {},
                rsid: child[:rsid]
              }
            end
          end
        end
      end

      # Handle direct 'children' (used for categories like Rückstellungen)
      if data[:children] && data[:items].nil?
        # Wrap in a single item to match the nested structure
        data[:children].each do |child|
          child_key = name_to_key(child[:name])
          category[:children][child_key] = {
            name: child[:name],
            codes: ensure_codes_array(child[:codes]),
            children: {},
            rsid: child[:rsid]
          }
        end
      end

      category
    end

    # Convert German name to symbol key
    # @param name [String, Symbol] German category name
    # @return [Symbol] Key for the category
    def name_to_key(name)
      # Convert to string if it's a symbol
      name_str = name.to_s

      # Normalize the name to create a consistent key
      key = name_str.downcase
        .gsub(/ä/, "ae")
        .gsub(/ö/, "oe")
        .gsub(/ü/, "ue")
        .gsub(/ß/, "ss")
        .gsub(/[^a-z0-9]+/, "_")
        .gsub(/^_+|_+$/, "")
        .to_sym

      # Handle special cases for known keys
      case name_str
      when "Anlagevermögen" then :anlagevermoegen
      when "Umlaufvermögen" then :umlaufvermoegen
      when "Rechnungsabgrenzungsposten" then :rechnungsabgrenzungsposten
      when "Aktive latente Steuern" then :aktive_latente_steuern
      when "Aktiver Unterschiedsbetrag aus der Vermögensverrechnung" then :aktiver_unterschiedsbetrag
      when "Eigenkapital" then :eigenkapital
      when "Rückstellungen" then :rueckstellungen
      when "Verbindlichkeiten" then :verbindlichkeiten
      when "Passive latente Steuern" then :passive_latente_steuern
      when "Immaterielle Vermögensgegenstände" then :immaterielle_vermogensgegenstaende
      when "Sachanlagen" then :sachanlagen
      when "Finanzanlagen" then :finanzanlagen
      when "Vorräte" then :vorraete
      when "Forderungen und sonstige Vermögensgegenstände" then :forderungen_sonstige_vermogensgegenstaende
      when "Wertpapiere" then :wertpapiere_umlaufvermoegen
      when "Kassenbestand, Bundesbankguthaben, Guthaben bei Kreditinstituten und Schecks" then :liquide_mittel
      when "Gezeichnetes Kapital" then :gezeichnetes_kapital
      when "Kapitalrücklage" then :kapitalruecklage
      when "Gewinnrücklagen" then :gewinnruecklagen
      when "Gewinnvortrag/Verlustvortrag" then :gewinnvortrag_verlustvortrag
      else
        key
      end
    end

    # Validate that the section_id exists in GUV_SECTIONS
    def validate_guv_section!(section_id)
      unless GUV_SECTIONS.key?(section_id)
        raise ArgumentError, "Unknown GuV section: #{section_id}. Valid sections: #{GUV_SECTIONS.keys.join(', ')}"
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

    # Validate that category exists in nested structure
    def validate_nested_category!(category_id)
      valid_aktiva = nested_balance_sheet_categories[:aktiva].keys
      valid_passiva = nested_balance_sheet_categories[:passiva].keys
      valid_categories = valid_aktiva + valid_passiva

      unless valid_categories.include?(category_id)
        raise ArgumentError, "Unknown nested category: #{category_id}. Valid categories: #{valid_categories.join(', ')}"
      end
    end

    # Find a category in the nested structure (recursive search)
    def find_in_nested_structure(category_id)
      # Search aktiva
      nested_balance_sheet_categories[:aktiva].each do |key, data|
        found = search_category_recursive(key, data, category_id)
        return found if found
      end

      # Search passiva
      nested_balance_sheet_categories[:passiva].each do |key, data|
        found = search_category_recursive(key, data, category_id)
        return found if found
      end

      nil
    end

    def search_category_recursive(current_key, current_data, target_key)
      return current_data if current_key == target_key

      if current_data[:children]
        current_data[:children].each do |child_key, child_data|
          found = search_category_recursive(child_key, child_data, target_key)
          return found if found
        end
      end

      nil
    end

    # Collect all codes from a structure and its children
    def collect_all_codes(structure)
      codes = structure[:codes] || []

      if structure[:children]
        structure[:children].each_value do |child_data|
          codes.concat(collect_all_codes(child_data))
        end
      end

      expand_account_ranges(codes)
    end

    # Recursively build BalanceSheetSection tree
    def build_section_recursive(account_list, section_key, structure, level:)
      # Get codes for this level only (not children)
      own_codes = expand_account_ranges(structure[:codes] || [])

      # Filter accounts that belong to this level
      own_accounts = account_list.select { |account| own_codes.include?(account[:code]) }

      # Create section
      section = BalanceSheetSection.new(
        section_key: section_key,
        section_name: structure[:name],
        level: level,
        accounts: own_accounts
      )

      # Recursively build children
      if structure[:children]
        structure[:children].each do |child_key, child_data|
          child_section = build_section_recursive(
            account_list,
            child_key,
            child_data,
            level: level + 1
          )
          section.add_child(child_section) unless child_section.empty?
        end
      end

      section
    end

    # Check if account requires special category handling (stub for future implementation)
    # @param account_code [String] The account code
    # @return [String, nil] Account type if special handling applies, nil otherwise
    def check_special_category_handling(account_code)
      # TODO: Implement special handling for:
      # - Rechnungsabgrenzungsposten (ARAP/PRAP)
      # - Latente Steuern (aktiv/passiv)
      # - Sonderposten mit Rücklageanteil
      # - Aktiver Unterschiedsbetrag aus Vermögensverrechnung
      nil
    end

    # Find account in nested balance sheet structure
    # @param account_code [String] The account code to search for
    # @return [Hash, nil] Hash with :side and :top_level_category, or nil if not found
    def find_account_in_nested_structure(account_code)
      # Search aktiva
      nested_balance_sheet_categories[:aktiva].each do |top_key, top_data|
        if account_in_category?(account_code, top_data)
          return { side: :aktiva, top_level_category: top_key }
        end
      end

      # Search passiva
      nested_balance_sheet_categories[:passiva].each do |top_key, top_data|
        if account_in_category?(account_code, top_data)
          return { side: :passiva, top_level_category: top_key }
        end
      end

      nil
    end

    # Check if account code exists in a category (recursively checks children)
    # @param account_code [String] The account code to search for
    # @param category_data [Hash] Category data with :codes and :children
    # @return [Boolean] True if account found in this category or its children
    def account_in_category?(account_code, category_data)
      # Check codes at this level
      codes = expand_account_ranges(category_data[:codes] || [])
      return true if codes.include?(account_code)

      # Recursively check children
      if category_data[:children]
        category_data[:children].each_value do |child_data|
          return true if account_in_category?(account_code, child_data)
        end
      end

      false
    end

    # Determine account type from balance sheet position
    # @param side [Symbol] :aktiva or :passiva
    # @param top_level_category [Symbol] The top-level category key
    # @return [String] The account type ("asset", "liability", or "equity")
    def account_type_from_balance_position(side, top_level_category)
      case side
      when :aktiva
        "asset"
      when :passiva
        case top_level_category
        when :eigenkapital
          "equity"
        when :rueckstellungen, :verbindlichkeiten
          "liability"
        else
          "liability"  # Conservative default for passiva
        end
      end
    end

    # Find which GuV section an account belongs to
    # @param account_code [String] The account code
    # @return [Symbol, nil] The GuV section identifier or nil if not found
    def find_guv_section_for_account(account_code)
      GUV_SECTIONS.each do |section_id, section_data|
        codes = expand_account_ranges(section_data[:accounts])
        return section_id if codes.include?(account_code)
      end
      nil
    end

    # Ensure codes is always an array (handles nil, empty strings, etc.)
    # @param codes [Object] Value that should be an array of codes
    # @return [Array] Array of codes (empty if input was invalid)
    def ensure_codes_array(codes)
      codes.is_a?(Array) ? codes : []
    end
  end
end
