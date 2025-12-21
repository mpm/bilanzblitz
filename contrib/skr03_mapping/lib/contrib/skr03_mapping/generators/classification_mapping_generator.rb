# frozen_string_literal: true

require 'json'
require 'yaml'
require 'set'

module Contrib
  module SKR03Mapping
    module Generators
      # Generates intermediate YAML mapping from official HGB structure to SKR03 classifications.
      #
      # This generator performs fuzzy matching between official HGB category names (from balance
      # sheet and GuV structures) and SKR03 account classifications (from OCR results). The output
      # is a human-editable YAML file that can be reviewed and corrected before generating final
      # JSON mapping files.
      #
      # Key responsibilities:
      # - Load HGB structures (bilanz aktiva/passiva, GuV)
      # - Load SKR03 classifications from OCR results
      # - Perform fuzzy matching using Utils::FuzzyMatcher
      # - Generate hierarchical category IDs using Utils::CategoryIdGenerator
      # - Track matching statistics (auto-matched, calculated, unmatched)
      # - Identify unmatched SKR03 classifications for manual review
      class ClassificationMappingGenerator
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

        attr_reader :stats

        # Initializes the generator with data from specified directory.
        #
        # @param data_dir [String] Directory containing input JSON files (default: current directory)
        def initialize(data_dir = ".")
          @data_dir = data_dir
          @bilanz_aktiva = JSON.parse(File.read(File.join(@data_dir, "hgb-bilanz-aktiva.json")))
          @bilanz_passiva = JSON.parse(File.read(File.join(@data_dir, "hgb-bilanz-passiva.json")))
          @guv = JSON.parse(File.read(File.join(@data_dir, "hgb-guv.json")))

          # Parse SKR03 classifications
          @skr03_classifications = parse_skr03_classifications

          # Track which SKR03 classifications are used in matching
          @used_skr03_classifications = Set.new

          # Statistics
          @stats = {
            total_hgb_categories: 0,
            auto_matched: 0,
            calculated: 0,
            unmatched: 0
          }
        end

        # Generates the classification mapping data structure.
        #
        # @return [Hash] Mapping structure with 'aktiva', 'passiva', and 'guv' keys
        def generate
          mapping = {
            "aktiva" => generate_balance_sheet_mapping(@bilanz_aktiva, "aktiva"),
            "passiva" => generate_balance_sheet_mapping(@bilanz_passiva, "passiva"),
            "guv" => generate_guv_mapping
          }

          mapping
        end

        # Gets list of unmatched SKR03 classifications.
        #
        # @return [Array<String>] Sorted array of SKR03 classifications not used in mapping
        def unmatched_skr03_classifications
          unmatched = @skr03_classifications.reject { |cat| @used_skr03_classifications.include?(cat) }
          unmatched.sort
        end

        # Writes mapping data to YAML file with documentation.
        #
        # @param output_path [String] Path to output YAML file
        # @param mapping [Hash] Mapping data structure from generate()
        def write_yaml(output_path, mapping)
          unmatched_skr03 = unmatched_skr03_classifications

          File.open(output_path, "w") do |f|
            f.puts "# SKR03 to HGB Classification Mapping"
            f.puts "# ================================"
            f.puts "#"
            f.puts "# This file maps official HGB balance sheet and GuV categories to SKR03 account classifications."
            f.puts "# It can be manually edited to fix incorrect matches before generating final JSON files."
            f.puts "#"
            f.puts "# Field Definitions:"
            f.puts "#   name: Official HGB category name (for reference)"
            f.puts "#   match_status:"
            f.puts "#     - auto: Automatically matched by fuzzy matching"
            f.puts "#     - manual: Manually specified/corrected"
            f.puts "#     - calculated: Calculated value, no direct account mapping"
            f.puts "#     - none: No match found (needs review)"
            f.puts "#   skr03_classification: Name of SKR03 account classification to map (or null)"
            f.puts "#   notes: Human-readable notes for documentation"
            f.puts "#"
            f.puts "# _meta sections are for parent/intermediate categories without direct account mappings."
            f.puts "# Leaf nodes (actual mappings) don't use _meta - they ARE the mapping."
            f.puts
            f.write YAML.dump(mapping)

            # Add unmatched SKR03 classifications as comments
            if unmatched_skr03.any?
              f.puts
              f.puts "# =============================================================================="
              f.puts "# UNMATCHED SKR03 CLASSIFICATIONS"
              f.puts "# =============================================================================="
              f.puts "#"
              f.puts "# The following SKR03 classifications were NOT matched to any HGB category."
              f.puts "# This means the accounts in these classifications will not appear in the balance"
              f.puts "# sheet or GuV reports unless you manually add them to the mapping above."
              f.puts "#"
              f.puts "# To fix: For each classification below, find the appropriate HGB category in the"
              f.puts "# mapping above and manually set its skr03_classification field."
              f.puts "#"
              f.puts "# Total unmatched: #{unmatched_skr03.length}"
              f.puts "#"
              unmatched_skr03.each do |classification|
                f.puts "# - #{classification}"
              end
              f.puts "#"
              f.puts "# =============================================================================="
            end
          end
        end

        # Prints generation statistics to stdout.
        def print_stats
          unmatched_skr03 = unmatched_skr03_classifications

          puts "\n"
          puts "=" * 80
          puts "Classification Mapping Statistics"
          puts "=" * 80
          puts
          puts "HGB Categories Statistics:"
          puts "  Total HGB categories: #{@stats[:total_hgb_categories]}"
          puts "  Auto-matched: #{@stats[:auto_matched]}"
          puts "  Calculated: #{@stats[:calculated]}"
          puts "  Unmatched HGB categories (needs review): #{@stats[:unmatched]}"
          puts
          puts "SKR03 Classifications Statistics:"
          puts "  Total SKR03 classifications: #{@skr03_classifications.length}"
          puts "  Used in mapping: #{@used_skr03_classifications.size}"
          puts "  Unmatched SKR03 classifications: #{unmatched_skr03.length}"
          puts
          if unmatched_skr03.any?
            puts "⚠️  WARNING: #{unmatched_skr03.length} SKR03 classifications were not matched!"
            puts "   These accounts will be missing from your balance sheet/GuV."
            puts "   See the end of skr03-section-mapping.yml for the full list."
            puts
          end
        end

        private

        def parse_skr03_classifications
          ocr_data = JSON.parse(File.read(File.join(@data_dir, "skr03-ocr-results.json")))
          classifications = {}

          ocr_data.each do |row|
            classification_name = row[0]&.strip
            next if classification_name.nil? || classification_name.empty?

            classifications[classification_name] = true
          end

          classifications.keys
        end

        def generate_balance_sheet_mapping(data, side)
          result = {}
          used_ids = []

          data.each do |section_name, section_data|
            section_id = Utils::CategoryIdGenerator.generate_id(section_name, used_ids)
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
            (matched, _unmatched) = Utils::FuzzyMatcher.fuzzy_match([ name ], @skr03_classifications)
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
                item_id = Utils::CategoryIdGenerator.generate_id(item["name"], used_ids)
                used_ids << item_id
                section[item_id] = process_balance_item(item, used_ids)
              elsif item["children"]
                # Item without name, process children directly
                item["children"].each do |child_name|
                  clean_child_name = child_name.gsub(/;$/, '')
                  child_id = Utils::CategoryIdGenerator.generate_id(clean_child_name, used_ids)
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
            (matched, _unmatched) = Utils::FuzzyMatcher.fuzzy_match([ name ], @skr03_classifications)
            match_result = matched[name]
          end

          has_children = item["children"] && !item["children"].empty?

          if has_children
            # Item with children
            section = {}
            section["_meta"] = build_meta(name, is_calculated, match_result)

            item["children"].each do |child_name|
              clean_child_name = child_name.gsub(/;$/, '')
              child_id = Utils::CategoryIdGenerator.generate_id(clean_child_name, used_ids)
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
              "skr03_classification" => nil,
              "notes" => "Calculated field, no direct account mapping"
            }
          end

          # Try to match
          (matched, _unmatched) = Utils::FuzzyMatcher.fuzzy_match([ name ], @skr03_classifications)
          match_result = matched[name]

          if match_result[:no_match]
            @stats[:unmatched] += 1
            {
              "name" => name,
              "match_status" => "none",
              "skr03_classification" => nil,
              "notes" => "No match found - needs manual review"
            }
          else
            @stats[:auto_matched] += 1
            # Track that this SKR03 classification was used
            @used_skr03_classifications.add(match_result[:original_classification])
            {
              "name" => name,
              "match_status" => "auto",
              "skr03_classification" => match_result[:original_classification],
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
              "skr03_classification" => nil,
              "notes" => "Parent category - sum of children"
            }
          elsif match_result && match_result[:no_match]
            @stats[:unmatched] += 1
            {
              "name" => name,
              "match_status" => "none",
              "skr03_classification" => nil,
              "notes" => "No match found - needs manual review"
            }
          elsif match_result
            @stats[:auto_matched] += 1
            # Track that this SKR03 classification was used
            @used_skr03_classifications.add(match_result[:original_classification])
            {
              "name" => name,
              "match_status" => "auto",
              "skr03_classification" => match_result[:original_classification],
              "notes" => match_result[:partial] ? "Partial match (case difference or similar)" : ""
            }
          else
            # No match attempted (shouldn't happen but handle it)
            @stats[:unmatched] += 1
            {
              "name" => name,
              "match_status" => "none",
              "skr03_classification" => nil,
              "notes" => "No match found"
            }
          end
        end

        def generate_guv_mapping
          result = {}
          used_ids = []

          @guv.each do |section_name, children|
            @stats[:total_hgb_categories] += 1

            section_id = Utils::CategoryIdGenerator.generate_id(section_name, used_ids)
            used_ids << section_id

            is_calculated = CALCULATED_CATEGORIES.include?(section_name)

            if is_calculated
              @stats[:calculated] += 1
              result[section_id] = {
                "name" => section_name,
                "match_status" => "calculated",
                "skr03_classification" => nil,
                "notes" => "Calculated field, no direct account mapping"
              }
            else
              # Try to match
              (matched, _unmatched) = Utils::FuzzyMatcher.fuzzy_match([ section_name ], @skr03_classifications)
              match_result = matched[section_name]

              if match_result[:no_match]
                @stats[:unmatched] += 1
                result[section_id] = {
                  "name" => section_name,
                  "match_status" => "none",
                  "skr03_classification" => nil,
                  "notes" => "No match found - needs manual review"
                }
              else
                @stats[:auto_matched] += 1
                # Track that this SKR03 classification was used
                @used_skr03_classifications.add(match_result[:original_classification])
                result[section_id] = {
                  "name" => section_name,
                  "match_status" => "auto",
                  "skr03_classification" => match_result[:original_classification],
                  "notes" => match_result[:partial] ? "Partial match (case difference or similar)" : ""
                }
              end
            end

            # Process children if they exist
            if children && !children.empty?
              children.each do |child_name|
                @stats[:total_hgb_categories] += 1

                child_id = Utils::CategoryIdGenerator.generate_id(child_name, used_ids)
                used_ids << child_id

                is_calculated_child = CALCULATED_CATEGORIES.include?(child_name)

                if is_calculated_child
                  @stats[:calculated] += 1
                  result[section_id][child_id] = {
                    "name" => child_name,
                    "match_status" => "calculated",
                    "skr03_classification" => nil,
                    "notes" => "Calculated field, no direct account mapping"
                  }
                else
                  (matched, _unmatched) = Utils::FuzzyMatcher.fuzzy_match([ child_name ], @skr03_classifications)
                  child_match = matched[child_name]

                  if child_match[:no_match]
                    @stats[:unmatched] += 1
                    result[section_id][child_id] = {
                      "name" => child_name,
                      "match_status" => "none",
                      "skr03_classification" => nil,
                      "notes" => "No match found - needs manual review"
                    }
                  else
                    @stats[:auto_matched] += 1
                    # Track that this SKR03 classification was used
                    @used_skr03_classifications.add(child_match[:original_classification])
                    result[section_id][child_id] = {
                      "name" => child_name,
                      "match_status" => "auto",
                      "skr03_classification" => child_match[:original_classification],
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
    end
  end
end
