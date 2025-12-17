#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Chart of Accounts Parser for SKR03
# ===================================
#
# This script parses OCR-extracted SKR03 chart of accounts data and generates
# structured JSON files that map German accounting standard categories (GuV and Bilanz)
# to their corresponding account codes.
#
# Input Files:
# - skr03-ocr-results.json: OCR results from SKR03 PDF (category → account codes)
# - bilanz-aktiva.json: Balance sheet structure (Aktiva/Assets)
# - bilanz-passiva.json: Balance sheet structure (Passiva/Liabilities & Equity)
# - guv.json: Profit & Loss (GuV) structure according to § 275 Abs. 2 HGB
#
# Output Files:
# - skr03-accounts.csv: All account codes with descriptions and category hashes
# - bilanz-with-categories.json: Balance sheet with category IDs and account codes
# - guv-with-categories.json: GuV with category IDs and account codes
#
# The script uses fuzzy matching to associate parsed category names with official
# German accounting category names, then maps them to account codes.

require 'json'
require 'digest'

# ParserTools provides stateless helper methods for parsing and matching
# chart of accounts data.
class ParserTools
  # These flags are used in the "Programmfunktion" Spalte (which should be ignored).
  # However, they indicate some of the account numbers listed in black framed boxes in the right column
  # Not sure what these are for, but they are duplicates and should be superseeded by the dedicated account descriptions
  # for these account codes.
  PROG_FUNC_FLAGS = %w[KU V M]

  # Parses an account code string from the OCR results.
  #
  # @param str [String] The raw string containing account code, optional range, and description
  # @return [Hash] Hash with :flags, :code, :range, and :description keys
  #
  # Examples:
  #   parse_code_string("4000-4999 Sales Revenue")
  #   # => { flags: "", code: "4000", range: "4000-4999", description: "Sales Revenue" }
  #
  #   parse_code_string("1320-26 Trade Receivables")
  #   # => { flags: "", code: "1320", range: "1320-1326", description: "Trade Receivables" }
  def self.parse_code_string(str)
    result = {
      flags: "",
      code: "",
      range: "",
      description: ""
    }

    # Main regex:
    # 1) flags (letters + spaces, optional)
    # 2) code (4 digits)
    # 3) optional range (-2 or -4 digits)
    # 4) description (rest)
    regex = /
      \A
      (?<flags>[A-Za-z\s\/]*?)?
      \s*
      (?<code>\d{4,5})
      (?<range_part>-\d{4,5}|\-\d{2})?
      \s*
      (?<description>.*)
      \z
    /x

    match = str.match(regex)
    return result unless match

    flags = (match[:flags] || "").strip
    code  = match[:code]
    range_part = match[:range_part]
    description = (match[:description] || "").strip

    # Build range if present
    range = ""
    if range_part
      end_digits = range_part.delete("-")

      if end_digits.length == 2
        # Example: 1320-26 → 1320-1326
        prefix = code[0, 2]
        range = "#{code}-#{prefix}#{end_digits}"
      else
        # Example: 0600-0800
        range = "#{code}-#{end_digits}"
      end
    end

    result[:flags] = flags
    result[:code] = code
    result[:range] = range
    result[:description] = description

    result
  end

  # Generates a 7-character hash ID for a category name.
  # This is used as a unique identifier (cid) for categories.
  #
  # @param category [String] The category name to hash
  # @return [String] 7-character hex hash
  def self.category_hash(category)
    Digest::SHA1.hexdigest(category)[0..6]
  end

  # Performs fuzzy matching between official category names and parsed category names.
  # Uses case-insensitive prefix matching, prioritizing longer overlaps and exact matches.
  #
  # @param official_names [Array<String>] Official category names from GuV/Bilanz structures
  # @param category_names [Array<String>] Parsed category names from OCR results
  # @return [Array<Hash, Array>] Tuple of [matched_hash, unmatched_categories]
  #   - matched_hash: Maps official names to match results (:original_category, :partial, :no_match)
  #   - unmatched_categories: Array of category names that weren't matched
  def self.fuzzy_match(official_names, category_names)
    matches = []

    official_names.each_with_index do |official, oi|
      official_down = official.downcase

      category_names.each_with_index do |category, ci|
        category_down = category.downcase

        # Determine shorter / longer string (case-insensitive)
        if official_down.length <= category_down.length
          shorter_down = official_down
          longer_down  = category_down
          shorter_orig = official
        else
          shorter_down = category_down
          longer_down  = official_down
          shorter_orig = category
        end

        # Case-insensitive prefix match
        next unless longer_down.start_with?(shorter_down)

        matches << {
          official_index: oi,
          category_index: ci,
          official: official,
          category: category,
          overlap: shorter_down.length,
          exact: official_down == category_down,
          matched_part: shorter_orig[0, shorter_down.length]
        }
      end
    end

    # Sort matches by best first
    matches.sort_by! do |m|
      [
        -m[:overlap],          # longer overlap first
        m[:exact] ? 0 : 1      # exact matches first
      ]
    end

    used_officials  = {}
    used_categories = {}
    result = {}

    matches.each do |m|
      oi = m[:official_index]
      ci = m[:category_index]

      next if used_officials[oi] || used_categories[ci]

      used_officials[oi]  = true
      used_categories[ci] = true

      result[m[:official]] = {
        match: m[:matched_part],
        original_category: m[:category],
        partial: !m[:exact]
      }
    end

    # Officials with no match
    official_names.each_with_index do |official, oi|
      result[official] ||= { no_match: true }
    end

    # Unmatched categories
    unmatched_categories =
      category_names.each_with_index
                    .reject { |_, i| used_categories[i] }
                    .map(&:first)

    [ result, unmatched_categories ]
  end

  def self.deduplicate_by_code(items)
    result = []

    items.group_by { |item| item[:code] }.each do |code, group|
      case group.size
      when 1
        result << group.first

      when 2
        with_description = group.select { |i| !i[:description].to_s.strip.empty? }
        without_range = group.select { |i| i[:range].to_s.strip.empty? }

        # The KU, V and M flags are only found in the second column (which was removed) in the PDF.
        # If they are here, it means this record is from one of the boxed listings on the right column
        # (meaning unclear). These records should be ignored in this case.
        without_wrong_flags = group.select { |i| (PROG_FUNC_FLAGS & i[:flags].split(" ")).size == 0 }

        if with_description.size == 0
          if without_range.size == 1
            result << without_range.first
          elsif without_wrong_flags.size == 1
            result << without_wrong_flags.first
          else
            raise <<~ERROR
              Duplicate code #{code} with no description each. Don't know which to pick (would prefer one without range or one without wrong flags):
              #{group.map(&:inspect).join("\n")}
            ERROR
          end
        elsif with_description.size == 1
          result << with_description.first
        else
          raise <<~ERROR
            Duplicate code #{code} with invalid description state:
            #{group.map(&:inspect).join("\n")}
          ERROR
        end

      else
        raise "Code #{code} appears more than twice (#{group.size} times)"
      end
    end

    result
  end
end

# CharOfAccountsParser orchestrates the parsing workflow:
# 1. Loads input JSON files (bilanz-aktiva, bilanz-passiva, guv, skr03-ocr-results)
# 2. Parses and categorizes account codes from OCR results
# 3. Performs fuzzy matching between official names and parsed categories
# 4. Generates output files with category IDs (cid) and account code mappings
#
# The output files enable the BilanzBlitz application to map account codes
# to their corresponding GuV and balance sheet positions.
class CharOfAccountsParser
  # @return [Array<Array>] All parsed account codes as [category_name, code_info] tuples
  attr_reader :all_codes

  # @return [Array<Hash>] Deduplicated account codes with :code, :cat, :description, etc.
  attr_reader :parsed_codes

  # @return [Hash] Mapping of category names to their parsed items
  attr_reader :positions

  # These position keys are from obvious parsing fails, they all map to the "empty" positional key.
  # These headers that occured within the page (rare), they do not contain any accounts on the right column
  # ignore these entirely
  LEFT_SIDE_IGNORE_LIST = [ "GuV-Posten", "BilanzPosten" ]

  # These are inbetween headers in the list of items (no account code).
  # these will also be just ignored.
  RIGHT_SIDE_IGNORE_LIST = [ "Immaterielle Vermögensgegenstände",
                            "Sachanlagen",
                            "Finanzanlagen",
                            "Verbindlichkeiten",
                            "Kapital Kapitalgesellschaft",
                            "Kapitalrücklage",
                            "Gewinnrücklagen",
                            "Rückstellungen",
                            "Abgrenzungsposten",
                            "Wertpapiere",
                            "Forderungen und sonstige Vermögensgegenstände",
                            "Verbindlichkeiten",
                            "Sonstige betriebliche Aufwendungen",
                            "Zinsen und ähnliche Aufwendungen",
                            "Steuern vom Einkommen und Ertrag",
                            "Sonstige Aufwendungen",
                            "Sonstige betriebliche Erträge",
                            "Zinserträge",
                            "Sonstige Erträge",
                            "Verrechnete kalkulatorische Kosten",
                            "Bestand an Vorräten",
                            "Verrechnete Stoffkosten",
                            "Personalaufwendungen",
                            "Sonstige betriebliche Aufwendungen und Abschreibungen",
                            "Kalkulatorische Kosten",
                            "Kapital Eigenkapital Vollhafter/Einzelunternehmer",
                            "Konten für die Verbuchung von Sonderbetriebseinnahmen",
                            "Statistische Konten für die im Anhang anzugebenden sonstigen finanziellen Verpflichtungen",
                            "Kosten bei Anwendung des Umsatzkostenverfahrens" ]

  def initialize
    @bilanz_aktiva = JSON.parse(File.readlines("bilanz-aktiva.json").join("\n"))
    @bilanz_passiva = JSON.parse(File.readlines("bilanz-passiva.json").join("\n"))
    @guv = JSON.parse(File.readlines("guv.json").join("\n"))

    @positions = {}

    no = 0
    ocr_data = JSON.parse(File.read("skr03-ocr-results.json"))

    puts "--- Parsing and sanity checking account data:\n"

    @all_codes = []
    ocr_data.each do |row|
      no += 1
      # row is [left_column_text, right_column_text]
      # Left column is Position Description
      # Right column is Items (semicolon separated)

      pos_desc = row[0]&.strip
      r3 = row[1] # Right column text

      if LEFT_SIDE_IGNORE_LIST.include?(pos_desc)
        puts "INFO: ignoring row with category #{pos_desc}"
      else

        pos_desc = "(none)" if pos_desc == ""

        pdata = positions[pos_desc] ||= { name: pos_desc, items: [] }

        # split string with ";" and discard strings without a four digit number anywhere (likely headers etc.)
        items = r3&.split(";")&.map(&:strip)
        if items
          items = items.reject { |item| RIGHT_SIDE_IGNORE_LIST.include?(item) }
          account_codes = items.select { |item| item =~ /\d{4,5}/ }
          non_account_codes = items.reject { |item| item =~ /\d{4,5}/ }

          if non_account_codes.size > 0
            puts "WARNING! Ignoring items (no account code found) [fix this in skr03-ocr-results.json]: #{non_account_codes.inspect}"
          end
          pdata[:items] += account_codes
          account_codes.each { |ac| all_codes << [ pos_desc, ac ] }
        end
      end
    end
  end

  # Associates balance sheet official names with parsed categories via fuzzy matching.
  # Builds a transformed structure with category IDs (cid), matched category names,
  # and associated account codes for each section, item, and child.
  #
  # @param bdata [Hash] Balance sheet data (from bilanz-aktiva.json or bilanz-passiva.json)
  # @param positions [Hash] Parsed category positions from OCR results
  # @param cid_to_codes [Hash] Mapping from category ID to account codes
  # @return [Hash] Transformed balance sheet structure with cid and codes attributes
  def associate_balance_sheet_names(bdata, positions, cid_to_codes = {})
    category_names = positions.keys

    balance_categories = []
    bdata.keys.each do |k|
      sublist = bdata[k]
      balance_categories << k

      sublist.each do |item|
        balance_categories << item["name"]
        item["children"].each do |child|
          balance_categories << child.gsub(/;$/, '') # remove semicolon
        end
      end
    end

    (matched, unmatched) = ParserTools.fuzzy_match(balance_categories, category_names)

    # Print matching results for verification
    matched.each do |key, result|
      puts "\n#{key}"
      if result[:no_match]
        puts "  --> (keine Kategorie gefunden)"
      else
        p = result[:partial] ? "[P] " : ""
        cid = ParserTools.category_hash(result[:original_category])
        puts "  --> #{p}#{result[:original_category]} (cid: #{cid})"
      end
    end

    # Build transformed structure
    transformed_bilanz = {}

    bdata.keys.each do |section_name|
      section_match = matched[section_name]

      # Create section object with cid and matched_category
      section_obj = {}
      if section_match && !section_match[:no_match]
        cid = ParserTools.category_hash(section_match[:original_category])
        section_obj[:cid] = cid
        section_obj[:matched_category] = section_match[:original_category]
        section_obj[:codes] = cid_to_codes[cid] || []
      else
        section_obj[:cid] = nil
        section_obj[:matched_category] = nil
        section_obj[:codes] = []
      end

      # Process items in this section
      items_array = bdata[section_name]
      if items_array && items_array.size > 0
        section_obj[:items] = items_array.map do |item|
          item_name = item["name"]
          item_match = matched[item_name]

          item_obj = {}
          if item_name && !item_name.empty?
            item_obj[:name] = item_name

            if item_match && !item_match[:no_match]
              cid = ParserTools.category_hash(item_match[:original_category])
              item_obj[:cid] = cid
              item_obj[:matched_category] = item_match[:original_category]
              item_obj[:codes] = cid_to_codes[cid] || []
            else
              item_obj[:cid] = nil
              item_obj[:matched_category] = nil
              item_obj[:codes] = []
            end
          end

          # Process children if they exist
          children_array = item["children"]
          if children_array && children_array.size > 0
            item_obj[:children] = children_array.map do |child_name|
              # Remove trailing semicolon
              clean_child_name = child_name.gsub(/;$/, '')
              child_match = matched[clean_child_name]

              child_obj = { name: clean_child_name }

              if child_match && !child_match[:no_match]
                cid = ParserTools.category_hash(child_match[:original_category])
                child_obj[:cid] = cid
                child_obj[:matched_category] = child_match[:original_category]
                child_obj[:codes] = cid_to_codes[cid] || []
              else
                child_obj[:cid] = nil
                child_obj[:matched_category] = nil
                child_obj[:codes] = []
              end

              child_obj
            end
          end

          item_obj
        end
      end

      transformed_bilanz[section_name] = section_obj
    end

    transformed_bilanz
  end

  # Associates GuV (Profit & Loss) official names with parsed categories via fuzzy matching.
  # Builds a transformed structure with category IDs (cid), matched category names,
  # and associated account codes for each section and child.
  #
  # @param bdata [Hash] GuV data (from guv.json) following § 275 Abs. 2 HGB structure
  # @param positions [Hash] Parsed category positions from OCR results
  # @param cid_to_codes [Hash] Mapping from category ID to account codes
  # @return [Hash] Transformed GuV structure with cid and codes attributes
  def associate_guv_names(bdata, positions, cid_to_codes = {})
    category_names = positions.keys

    guv_categories = []
    bdata.keys.each do |k|
      guv_categories << k

      bdata[k].each do |item|
        guv_categories << item
      end
    end

    (matched, unmatched) = ParserTools.fuzzy_match(guv_categories, category_names)

    # Print matching results for verification
    matched.each do |key, result|
      puts "\n#{key}"
      if result[:no_match]
        puts "  --> (keine Kategorie gefunden)"
      else
        p = result[:partial] ? "[P] " : ""
        cid = ParserTools.category_hash(result[:original_category])
        puts "  --> #{p}#{result[:original_category]} (cid: #{cid})"
      end
    end

    # Build transformed structure
    transformed_guv = {}

    bdata.each do |section_name, children|
      match_result = matched[section_name]

      # Create section object with cid and matched_category
      section_obj = {}
      if match_result && !match_result[:no_match]
        cid = ParserTools.category_hash(match_result[:original_category])
        section_obj[:cid] = cid
        section_obj[:matched_category] = match_result[:original_category]
        section_obj[:codes] = cid_to_codes[cid] || []
      else
        section_obj[:cid] = nil
        section_obj[:matched_category] = nil
        section_obj[:codes] = []
      end

      # Add children if they exist
      if children && children.size > 0
        section_obj[:children] = children.map do |child_name|
          child_match = matched[child_name]
          child_obj = { name: child_name }

          if child_match && !child_match[:no_match]
            cid = ParserTools.category_hash(child_match[:original_category])
            child_obj[:cid] = cid
            child_obj[:matched_category] = child_match[:original_category]
            child_obj[:codes] = cid_to_codes[cid] || []
          else
            child_obj[:cid] = nil
            child_obj[:matched_category] = nil
            child_obj[:codes] = []
          end

          child_obj
        end
      end

      transformed_guv[section_name] = section_obj
    end

    transformed_guv
  end

  def create_skr03_accounts_csv!
    @parsed_codes = ParserTools.deduplicate_by_code(
      all_codes.map do |code_tuple|
        (category, code_info) = code_tuple
        result = ParserTools.parse_code_string(code_info)
        result[:cat] = ParserTools.category_hash(category)
        if result[:code] == ""
          raise "ERROR! parse_code_string failed (no code detected) for #{code_info.inspect}"
        end
        result
      end.select { |pc| (ParserTools::PROG_FUNC_FLAGS & pc[:flags].split(" ")).size == 0 }
    )

    File.open("skr03-accounts.csv", "w") do |f|
      f.puts "# This file was automatically generated by contrib/parse_chart_of_accounts.rb"
      f.puts "# Columns: code; flags; range; category; description"
      parsed_codes.each do |pc|
        f.puts "#{pc[:code]};#{pc[:flags]};#{pc[:range]};#{pc[:cat]};#{pc[:description]}"
      end
    end
    puts "Updated skr03-accounts.csv"
  end

  # Builds a mapping from category ID (cid) to account codes.
  # This allows looking up all account codes that belong to a specific category.
  #
  # @return [Hash<String, Array<String>>] Hash mapping cid to sorted array of account codes
  def build_cid_to_codes_mapping
    # Build a hash that maps from cid (cat) to array of account codes
    mapping = Hash.new { |h, k| h[k] = [] }

    parsed_codes.each do |pc|
      cat = pc[:cat]
      code = pc[:code]
      mapping[cat] << code if cat && code
    end

    # Sort codes for each category
    mapping.each do |cat, codes|
      codes.sort!
    end

    mapping
  end

  # Generates bilanz-with-categories.json and guv-with-categories.json files.
  # These files contain the complete mapping from German accounting standard
  # categories to their category IDs (cid) and associated SKR03 account codes.
  #
  # Output structure includes:
  # - cid: 7-character hash identifying the category
  # - matched_category: The original parsed category name
  # - codes: Array of account codes belonging to this category
  # - children: Nested sub-categories (where applicable)
  def create_balance_sheet_and_guv_with_categories!
    # Build mapping from cid to list of account codes
    cid_to_codes = build_cid_to_codes_mapping

    puts "--- associate_balance_sheet_names:"
    transformed_aktiva = associate_balance_sheet_names(@bilanz_aktiva, positions, cid_to_codes)
    transformed_passiva = associate_balance_sheet_names(@bilanz_passiva, positions, cid_to_codes)

    # Create unified balance sheet structure
    transformed_bilanz = {
      aktiva: transformed_aktiva,
      passiva: transformed_passiva
    }

    # Save the transformed balance sheet structure
    File.open("bilanz-with-categories.json", "w") do |f|
      f.puts JSON.pretty_generate(transformed_bilanz)
    end
    puts "\nUpdated bilanz-with-categories.json"

    puts "\n--- associate_guv_names:"
    transformed_guv = associate_guv_names(@guv, positions, cid_to_codes)

    # Save the transformed structure
    File.open("guv-with-categories.json", "w") do |f|
      f.puts JSON.pretty_generate(transformed_guv)
    end
    puts "\nUpdated guv-with-categories.json"
  end
end

parser = CharOfAccountsParser.new
parser.create_skr03_accounts_csv!
parser.create_balance_sheet_and_guv_with_categories!

puts "categories: #{parser.positions.keys.size}. total items (account code [ranges]): #{parser.all_codes.size}\n"
# puts "--- Listing all parsed account categories:"
# Use this to output a summary to check for reasonable keys (or misspellings and failed parsings):
# positions.keys.sort.each { |p| puts "#{p}: #{positions[p][:items].size}" }
