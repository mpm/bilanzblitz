#!/usr/bin/env ruby
# frozen_string_literal: true

#
# Category Mapping Generator for SKR03 to HGB
# ============================================
#
# This script generates an intermediate YAML mapping file that maps official HGB
# balance sheet and GuV categories to SKR03 categories from OCR results.
#
# The generated mapping can be manually edited before using build_category_json.rb
# to generate the final bilanz-sections-mapping.json and guv-sections-mapping.json files.
#
# Input Files:
# - hgb-bilanz-aktiva.json: Balance sheet structure (Aktiva/Assets)
# - hgb-bilanz-passiva.json: Balance sheet structure (Passiva/Liabilities & Equity)
# - hgb-guv.json: Profit & Loss (GuV) structure according to § 275 Abs. 2 HGB
# - skr03-ocr-results.json: OCR results from SKR03 PDF (category → account codes)
#
# Output Files:
# - skr03-section-mapping.yml: Intermediate mapping (human-editable)
# - Diagnostic report to STDOUT

require 'json'
require 'yaml'
require 'set'

# Utility class for generating hierarchical category IDs
class CategoryIdGenerator
  # Generates hierarchical category ID from German category name
  # @param name [String] The German category name
  # @param existing_ids [Array<String>] List of already used IDs to ensure uniqueness
  # @return [String] The generated ID
  def self.generate_id(name, existing_ids = [])
    # Convert to lowercase
    id = name.downcase

    # German character replacements
    id = id.gsub('ä', 'ae').gsub('ö', 'oe').gsub('ü', 'ue').gsub('ß', 'ss')

    # Remove punctuation and special chars
    id = id.gsub(/[,;:.()\[\]\/"']/, '')

    # Replace spaces and dashes with underscores
    id = id.gsub(/[\s\-]+/, '_')

    # Remove any remaining non-alphanumeric (except underscore)
    id = id.gsub(/[^a-z0-9_]/, '')

    # Collapse multiple underscores
    id = id.gsub(/_+/, '_')

    # Remove leading/trailing underscores
    id = id.gsub(/^_+|_+$/, '')

    # Truncate if too long (keep first 60 chars)
    id = id[0..59] if id.length > 60

    # Ensure uniqueness
    if existing_ids.include?(id)
      counter = 2
      while existing_ids.include?("#{id}_#{counter}")
        counter += 1
      end
      id = "#{id}_#{counter}"
    end

    id
  end
end

# Reuse fuzzy matching logic from parse_chart_of_accounts.rb
class FuzzyMatcher
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
end

# Main generator class
class CategoryMappingGenerator
  # Categories that should be marked as "calculated" (no direct account mapping)
  CALCULATED_CATEGORIES = [
    "Anlagevermögen",
    "Umlaufvermögen",
    "Rechnungsabgrenzungsposten",
    "Aktive latente Steuern",
    "Aktiver Unterschiedsbetrag aus der Vermögensverrechnung",
    "Immaterielle Vermögensgegenstände",
    "Sachanlagen",
    "Finanzanlagen",
    "Vorräte",
    "Forderungen und sonstige Vermögensgegenstände",
    "Wertpapiere",
    "Kassenbestand, Bundesbankguthaben, Guthaben bei Kreditinstituten und Schecks",
    "Eigenkapital",
    "Gezeichnetes Kapital",
    "Kapitalrücklage",
    "Gewinnrücklagen",
    "Gewinnvortrag/Verlustvortrag",
    "Jahresüberschuß/Jahresfehlbetrag",
    "Rückstellungen",
    "Verbindlichkeiten",
    "Passive latente Steuern",
    "Erhöhung oder Verminderung des Bestands an fertigen und unfertigen Erzeugnissen",
    "Ergebnis nach Steuern",
    "Jahresüberschuss/Jahresfehlbetrag",
    "Materialaufwand",
    "Personalaufwand",
    "Abschreibungen"
  ].freeze

  def initialize
    @bilanz_aktiva = JSON.parse(File.read("hgb-bilanz-aktiva.json"))
    @bilanz_passiva = JSON.parse(File.read("hgb-bilanz-passiva.json"))
    @guv = JSON.parse(File.read("hgb-guv.json"))

    # Parse SKR03 categories
    @skr03_categories = parse_skr03_categories

    # Track which SKR03 categories are used in matching
    @used_skr03_categories = Set.new

    # Statistics
    @stats = {
      total_hgb_categories: 0,
      auto_matched: 0,
      calculated: 0,
      unmatched: 0
    }
  end

  def generate
    puts "=" * 80
    puts "Category Mapping Generator - SKR03 to HGB"
    puts "=" * 80
    puts

    mapping = {
      "aktiva" => generate_balance_sheet_mapping(@bilanz_aktiva, "aktiva"),
      "passiva" => generate_balance_sheet_mapping(@bilanz_passiva, "passiva"),
      "guv" => generate_guv_mapping
    }

    # Calculate unmatched SKR03 categories
    unmatched_skr03 = @skr03_categories.reject { |cat| @used_skr03_categories.include?(cat) }
    unmatched_skr03 = unmatched_skr03.sort

    # Write YAML file
    File.open("skr03-section-mapping.yml", "w") do |f|
      f.puts "# SKR03 to HGB Category Mapping"
      f.puts "# ================================"
      f.puts "#"
      f.puts "# This file maps official HGB balance sheet and GuV categories to SKR03 categories."
      f.puts "# It can be manually edited to fix incorrect matches before generating final JSON files."
      f.puts "#"
      f.puts "# Field Definitions:"
      f.puts "#   name: Official HGB category name (for reference)"
      f.puts "#   match_status:"
      f.puts "#     - auto: Automatically matched by fuzzy matching"
      f.puts "#     - manual: Manually specified/corrected"
      f.puts "#     - calculated: Calculated value, no direct account mapping"
      f.puts "#     - none: No match found (needs review)"
      f.puts "#   skr03_category: Name of SKR03 category to map (or null)"
      f.puts "#   notes: Human-readable notes for documentation"
      f.puts "#"
      f.puts "# _meta sections are for parent/intermediate categories without direct account mappings."
      f.puts "# Leaf nodes (actual mappings) don't use _meta - they ARE the mapping."
      f.puts
      f.write YAML.dump(mapping)

      # Add unmatched SKR03 categories as comments
      if unmatched_skr03.any?
        f.puts
        f.puts "# =============================================================================="
        f.puts "# UNMATCHED SKR03 CATEGORIES"
        f.puts "# =============================================================================="
        f.puts "#"
        f.puts "# The following SKR03 categories were NOT matched to any HGB category."
        f.puts "# This means the accounts in these categories will not appear in the balance"
        f.puts "# sheet or GuV reports unless you manually add them to the mapping above."
        f.puts "#"
        f.puts "# To fix: For each category below, find the appropriate HGB category in the"
        f.puts "# mapping above and manually set its skr03_category field."
        f.puts "#"
        f.puts "# Total unmatched: #{unmatched_skr03.length}"
        f.puts "#"
        unmatched_skr03.each do |category|
          f.puts "# - #{category}"
        end
        f.puts "#"
        f.puts "# =============================================================================="
      end
    end

    puts "\n"
    puts "=" * 80
    puts "Category Mapping Generated: skr03-section-mapping.yml"
    puts "=" * 80
    puts
    puts "HGB Categories Statistics:"
    puts "  Total HGB categories: #{@stats[:total_hgb_categories]}"
    puts "  Auto-matched: #{@stats[:auto_matched]}"
    puts "  Calculated: #{@stats[:calculated]}"
    puts "  Unmatched HGB categories (needs review): #{@stats[:unmatched]}"
    puts
    puts "SKR03 Categories Statistics:"
    puts "  Total SKR03 categories: #{@skr03_categories.length}"
    puts "  Used in mapping: #{@used_skr03_categories.size}"
    puts "  Unmatched SKR03 categories: #{unmatched_skr03.length}"
    puts
    if unmatched_skr03.any?
      puts "⚠️  WARNING: #{unmatched_skr03.length} SKR03 categories were not matched!"
      puts "   These accounts will be missing from your balance sheet/GuV."
      puts "   See the end of skr03-section-mapping.yml for the full list."
      puts
    end
    puts "Next steps:"
    puts "  1. Review skr03-section-mapping.yml and fix any incorrect matches"
    puts "  2. Check unmatched SKR03 categories at the end of the file"
    puts "  3. Manually assign unmatched SKR03 categories to appropriate HGB categories"
    puts "  4. Run: ./dc ruby contrib/build_category_json.rb"
    puts
  end

  private

  def parse_skr03_categories
    ocr_data = JSON.parse(File.read("skr03-ocr-results.json"))
    categories = {}

    ocr_data.each do |row|
      category_name = row[0]&.strip
      next if category_name.nil? || category_name.empty?

      categories[category_name] = true
    end

    categories.keys
  end

  def generate_balance_sheet_mapping(data, side)
    result = {}
    used_ids = []

    data.each do |section_name, section_data|
      section_id = CategoryIdGenerator.generate_id(section_name, used_ids)
      used_ids << section_id

      result[section_id] = process_balance_section(section_name, section_data, used_ids)
    end

    result
  end

  def process_balance_section(name, data, used_ids)
    @stats[:total_hgb_categories] += 1

    is_calculated = CALCULATED_CATEGORIES.include?(name)
    match_result = nil

    unless is_calculated
      # Try to match this category
      (matched, _unmatched) = FuzzyMatcher.fuzzy_match([ name ], @skr03_categories)
      match_result = matched[name]
    end

    section = {}

    # Determine if this has children/items
    has_items = data.is_a?(Array) && !data.empty?

    if has_items
      # This is a parent category with items
      section["_meta"] = build_meta(name, is_calculated, match_result)

      data.each do |item|
        if item["name"] && !item["name"].empty?
          # Item with a name
          item_id = CategoryIdGenerator.generate_id(item["name"], used_ids)
          used_ids << item_id
          section[item_id] = process_balance_item(item, used_ids)
        elsif item["children"]
          # Item without name, process children directly
          item["children"].each do |child_name|
            clean_child_name = child_name.gsub(/;$/, '')
            child_id = CategoryIdGenerator.generate_id(clean_child_name, used_ids)
            used_ids << child_id
            section[child_id] = process_balance_leaf(clean_child_name)
          end
        end
      end
    else
      # This is a leaf category
      return process_balance_leaf(name)
    end

    section
  end

  def process_balance_item(item, used_ids)
    name = item["name"]
    @stats[:total_hgb_categories] += 1

    is_calculated = CALCULATED_CATEGORIES.include?(name)
    match_result = nil

    unless is_calculated
      (matched, _unmatched) = FuzzyMatcher.fuzzy_match([ name ], @skr03_categories)
      match_result = matched[name]
    end

    has_children = item["children"] && !item["children"].empty?

    if has_children
      # Item with children
      section = {}
      section["_meta"] = build_meta(name, is_calculated, match_result)

      item["children"].each do |child_name|
        clean_child_name = child_name.gsub(/;$/, '')
        child_id = CategoryIdGenerator.generate_id(clean_child_name, used_ids)
        used_ids << child_id
        section[child_id] = process_balance_leaf(clean_child_name)
      end

      section
    else
      # Item without children (leaf)
      process_balance_leaf(name)
    end
  end

  def process_balance_leaf(name)
    @stats[:total_hgb_categories] += 1

    is_calculated = CALCULATED_CATEGORIES.include?(name)

    if is_calculated
      @stats[:calculated] += 1
      return {
        "name" => name,
        "match_status" => "calculated",
        "skr03_category" => nil,
        "notes" => "Calculated field, no direct account mapping"
      }
    end

    # Try to match
    (matched, _unmatched) = FuzzyMatcher.fuzzy_match([ name ], @skr03_categories)
    match_result = matched[name]

    if match_result[:no_match]
      @stats[:unmatched] += 1
      {
        "name" => name,
        "match_status" => "none",
        "skr03_category" => nil,
        "notes" => "No match found - needs manual review"
      }
    else
      @stats[:auto_matched] += 1
      # Track that this SKR03 category was used
      @used_skr03_categories.add(match_result[:original_category])
      {
        "name" => name,
        "match_status" => "auto",
        "skr03_category" => match_result[:original_category],
        "notes" => match_result[:partial] ? "Partial match (case difference or similar)" : ""
      }
    end
  end

  def build_meta(name, is_calculated, match_result)
    if is_calculated
      @stats[:calculated] += 1
      {
        "name" => name,
        "match_status" => "calculated",
        "skr03_category" => nil,
        "notes" => "Parent category - sum of children"
      }
    elsif match_result && match_result[:no_match]
      @stats[:unmatched] += 1
      {
        "name" => name,
        "match_status" => "none",
        "skr03_category" => nil,
        "notes" => "No match found - needs manual review"
      }
    elsif match_result
      @stats[:auto_matched] += 1
      # Track that this SKR03 category was used
      @used_skr03_categories.add(match_result[:original_category])
      {
        "name" => name,
        "match_status" => "auto",
        "skr03_category" => match_result[:original_category],
        "notes" => match_result[:partial] ? "Partial match (case difference or similar)" : ""
      }
    else
      # No match attempted (shouldn't happen but handle it)
      @stats[:unmatched] += 1
      {
        "name" => name,
        "match_status" => "none",
        "skr03_category" => nil,
        "notes" => "No match found"
      }
    end
  end

  def generate_guv_mapping
    result = {}
    used_ids = []

    @guv.each do |section_name, children|
      @stats[:total_hgb_categories] += 1

      section_id = CategoryIdGenerator.generate_id(section_name, used_ids)
      used_ids << section_id

      is_calculated = CALCULATED_CATEGORIES.include?(section_name)

      if is_calculated
        @stats[:calculated] += 1
        result[section_id] = {
          "name" => section_name,
          "match_status" => "calculated",
          "skr03_category" => nil,
          "notes" => "Calculated field, no direct account mapping"
        }
      else
        # Try to match
        (matched, _unmatched) = FuzzyMatcher.fuzzy_match([ section_name ], @skr03_categories)
        match_result = matched[section_name]

        if match_result[:no_match]
          @stats[:unmatched] += 1
          result[section_id] = {
            "name" => section_name,
            "match_status" => "none",
            "skr03_category" => nil,
            "notes" => "No match found - needs manual review"
          }
        else
          @stats[:auto_matched] += 1
          # Track that this SKR03 category was used
          @used_skr03_categories.add(match_result[:original_category])
          result[section_id] = {
            "name" => section_name,
            "match_status" => "auto",
            "skr03_category" => match_result[:original_category],
            "notes" => match_result[:partial] ? "Partial match (case difference or similar)" : ""
          }
        end
      end

      # Process children if they exist
      if children && !children.empty?
        children.each do |child_name|
          @stats[:total_hgb_categories] += 1

          child_id = CategoryIdGenerator.generate_id(child_name, used_ids)
          used_ids << child_id

          is_calculated_child = CALCULATED_CATEGORIES.include?(child_name)

          if is_calculated_child
            @stats[:calculated] += 1
            result[section_id][child_id] = {
              "name" => child_name,
              "match_status" => "calculated",
              "skr03_category" => nil,
              "notes" => "Calculated field, no direct account mapping"
            }
          else
            (matched, _unmatched) = FuzzyMatcher.fuzzy_match([ child_name ], @skr03_categories)
            child_match = matched[child_name]

            if child_match[:no_match]
              @stats[:unmatched] += 1
              result[section_id][child_id] = {
                "name" => child_name,
                "match_status" => "none",
                "skr03_category" => nil,
                "notes" => "No match found - needs manual review"
              }
            else
              @stats[:auto_matched] += 1
              # Track that this SKR03 category was used
              @used_skr03_categories.add(child_match[:original_category])
              result[section_id][child_id] = {
                "name" => child_name,
                "match_status" => "auto",
                "skr03_category" => child_match[:original_category],
                "notes" => child_match[:partial] ? "Partial match (case difference or similar)" : ""
              }
            end
          end
        end
      end
    end

    result
  end
end

# Run the generator
if __FILE__ == $PROGRAM_NAME
  Dir.chdir(File.dirname(__FILE__))
  generator = CategoryMappingGenerator.new
  generator.generate
end
