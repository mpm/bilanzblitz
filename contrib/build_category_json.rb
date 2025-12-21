#!/usr/bin/env ruby
# frozen_string_literal: true

#
# Classification JSON Builder
# ==========================
#
# Builds bilanz-sections-mapping.json and guv-sections-mapping.json
# from validated skr03-section-mapping.yml and skr03-ocr-results.json
#
# Input Files:
# - skr03-section-mapping.yml: Validated intermediate mapping (manually edited)
# - skr03-ocr-results.json: SKR03 classifications with account codes
# - hgb-bilanz-aktiva.json: Balance sheet structure (for structure reference)
# - hgb-bilanz-passiva.json: Balance sheet structure (for structure reference)
# - hgb-guv.json: GuV structure (for structure reference)
#
# Output Files:
# - bilanz-sections-mapping.json: Balance sheet with section IDs and codes
# - guv-sections-mapping.json: GuV with section IDs and codes

require 'json'
require 'yaml'

# Reuse parsing tools from parse_chart_of_accounts.rb
class ParserTools
  PROG_FUNC_FLAGS = %w[KU V M]

  # Parses an account code string from the OCR results.
  def self.parse_code_string(str)
    result = {
      flags: "",
      code: "",
      range: "",
      description: ""
    }

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

  def self.deduplicate_by_code(items)
    result = []

    items.group_by { |item| item[:code] }.each do |code, group|
      case group.size
      when 1
        result << group.first

      when 2
        with_description = group.select { |i| !i[:description].to_s.strip.empty? }
        without_range = group.select { |i| i[:range].to_s.strip.empty? }
        without_wrong_flags = group.select { |i| (PROG_FUNC_FLAGS & i[:flags].split(" ")).size == 0 }

        if with_description.size == 0
          if without_range.size == 1
            result << without_range.first
          elsif without_wrong_flags.size == 1
            result << without_wrong_flags.first
          else
            raise <<~ERROR
              Duplicate code #{code} with no description each. Don't know which to pick:
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

# Main builder class
class ClassificationJsonBuilder
  def initialize
    @mapping = YAML.load_file('skr03-section-mapping.yml')
    @bilanz_aktiva = JSON.parse(File.read('hgb-bilanz-aktiva.json'))
    @bilanz_passiva = JSON.parse(File.read('hgb-bilanz-passiva.json'))
    @guv = JSON.parse(File.read('hgb-guv.json'))

    # Load presentation rules mapping if available
    @presentation_rules = load_presentation_rules

    # Build SKR03 classification → account codes mapping
    @skr03_by_classification = build_skr03_index

    # Build SKR03 classification name → hierarchical cid mapping
    @skr03_classification_to_cid = build_classification_to_cid_mapping

    # Build SKR03 classification name → presentation rule mapping
    @skr03_classification_to_rule = build_classification_to_rule_mapping
  end

  # Load presentation rules from YAML file
  def load_presentation_rules
    rules_path = 'skr03-presentation-rules.yml'
    return nil unless File.exist?(rules_path)

    YAML.load_file(rules_path)
  rescue StandardError => e
    puts "Warning: Failed to load presentation rules: #{e.message}"
    nil
  end

  def build
    puts "=" * 80
    puts "Building Classification JSON Files from Mapping"
    puts "=" * 80
    puts

    # Build bilanz-sections-mapping.json
    bilanz_output = {
      aktiva: build_balance_sheet_side(@bilanz_aktiva, @mapping["aktiva"], "aktiva"),
      passiva: build_balance_sheet_side(@bilanz_passiva, @mapping["passiva"], "passiva")
    }

    File.open("bilanz-sections-mapping.json", "w") do |f|
      f.write JSON.pretty_generate(bilanz_output)
    end

    puts "✓ Generated bilanz-sections-mapping.json"

    # Build guv-sections-mapping.json
    guv_output = build_guv_structure
    File.open("guv-sections-mapping.json", "w") do |f|
      f.write JSON.pretty_generate(guv_output)
    end

    puts "✓ Generated guv-sections-mapping.json"

    # Generate skr03-accounts.csv
    generate_skr03_accounts_csv
    puts "✓ Generated skr03-accounts.csv"

    puts
    puts "Done! Final JSON files have been generated."
    puts
  end

  private

  # Build index: SKR03 classification name → account codes
  def build_skr03_index
    ocr_data = JSON.parse(File.read('skr03-ocr-results.json'))

    # Parse all account codes
    all_codes = []
    ocr_data.each do |row|
      classification_name = row[0]&.strip || ""
      right_column = row[1]

      next if classification_name.empty? && right_column.nil?

      items = right_column&.split(";")&.map(&:strip)
      next unless items

      account_codes = items.select { |item| item =~ /\d{4,5}/ }
      account_codes.each do |ac|
        all_codes << [ classification_name, ac ]
      end
    end

    # Parse and deduplicate
    parsed_codes = ParserTools.deduplicate_by_code(
      all_codes.map do |code_tuple|
        (classification, code_info) = code_tuple
        result = ParserTools.parse_code_string(code_info)
        result[:classification] = classification
        if result[:code] == ""
          raise "ERROR! parse_code_string failed for #{code_info.inspect}"
        end
        result
      end.select { |pc| (ParserTools::PROG_FUNC_FLAGS & pc[:flags].split(" ")).size == 0 }
    )

    # Build index
    index = Hash.new { |h, k| h[k] = [] }
    parsed_codes.each do |pc|
      classification = pc[:classification]
      code = pc[:code]
      index[classification] << code if classification && code
    end

    # Sort codes
    index.each { |_, codes| codes.sort! }

    index
  end

  # Build balance sheet side (aktiva or passiva)
  def build_balance_sheet_side(structure, mapping, side)
    result = {}
    # Add balance sheet prefix: b.aktiva or b.passiva
    prefix = "b.#{side}"

    structure.each do |section_name, section_data|
      # Find mapping for this section
      section_mapping = find_mapping_for_name(mapping, section_name)

      if section_mapping
        section_id = find_id_for_mapping(mapping, section_mapping)
        # Prepend balance sheet prefix to section_id
        full_section_id = "#{prefix}.#{section_id}"
        result[section_name] = build_balance_section(section_name, section_data, section_mapping, full_section_id, side)
      else
        # No mapping found - create empty structure
        result[section_name] = {
          rsid: nil,
          skr03_classification: nil,
          codes: []
        }
      end
    end

    result
  end

  def build_balance_section(name, data, mapping, path_prefix, side)
    meta = mapping["_meta"] if mapping.is_a?(Hash)

    classification_field = meta ? (meta["skr03_classification"] || meta["skr03_category"]) : (mapping["skr03_classification"] || mapping["skr03_category"])

    section = {
      rsid: path_prefix,
      skr03_classification: classification_field,
      codes: get_codes_for_mapping(meta || mapping)
    }

    # Process items array
    if data.is_a?(Array) && !data.empty?
      section[:items] = data.map do |item|
        if item["name"] && !item["name"].empty?
          # Item with name
          item_mapping = find_mapping_for_name(mapping, item["name"])
          if item_mapping
            item_id = find_id_for_mapping(mapping, item_mapping)
            build_balance_item(item, item_mapping, "#{path_prefix}.#{item_id}")
          else
            build_empty_item(item)
          end
        elsif item["children"]
          # Item without name, but with children
          build_nameless_item(item, mapping, path_prefix)
        else
          build_empty_item(item)
        end
      end
    end

    section
  end

  def build_balance_item(item, mapping, path_prefix)
    meta = mapping["_meta"] if mapping.is_a?(Hash)

    classification_field = meta ? (meta["skr03_classification"] || meta["skr03_category"]) : (mapping["skr03_classification"] || mapping["skr03_category"])

    item_obj = {
      name: item["name"],
      rsid: path_prefix,
      skr03_classification: classification_field,
      codes: get_codes_for_mapping(meta || mapping)
    }

    # Process children
    if item["children"] && !item["children"].empty?
      item_obj[:children] = item["children"].map do |child_name|
        clean_child_name = child_name.gsub(/;$/, '')
        child_mapping = find_mapping_for_name(mapping, clean_child_name)

        if child_mapping
          child_id = find_id_for_mapping(mapping, child_mapping)
          {
            name: clean_child_name,
            rsid: "#{path_prefix}.#{child_id}",
            skr03_classification: child_mapping["skr03_classification"] || child_mapping["skr03_category"],
            codes: get_codes_for_mapping(child_mapping)
          }
        else
          {
            name: clean_child_name,
            rsid: nil,
            skr03_classification: nil,
            codes: []
          }
        end
      end
    end

    item_obj
  end

  def build_nameless_item(item, mapping, path_prefix)
    {
      name: "",
      codes: "",
      children: item["children"].map do |child_name|
        clean_child_name = child_name.gsub(/;$/, '')
        child_mapping = find_mapping_for_name(mapping, clean_child_name)

        if child_mapping
          child_id = find_id_for_mapping(mapping, child_mapping)
          {
            name: clean_child_name,
            rsid: "#{path_prefix}.#{child_id}",
            skr03_classification: child_mapping["skr03_classification"] || child_mapping["skr03_category"],
            codes: get_codes_for_mapping(child_mapping)
          }
        else
          {
            name: clean_child_name,
            rsid: nil,
            skr03_classification: nil,
            codes: []
          }
        end
      end
    }
  end

  def build_empty_item(item)
    {
      name: item["name"] || "",
      rsid: nil,
      skr03_classification: nil,
      codes: []
    }
  end

  # Build GuV structure
  def build_guv_structure
    result = {}

    @guv.each do |section_name, children|
      section_mapping = find_mapping_for_name(@mapping["guv"], section_name)

      if section_mapping
        section_id = find_id_for_mapping(@mapping["guv"], section_mapping)

        section = {
          rsid: "guv.#{section_id}",
          skr03_classification: section_mapping["skr03_classification"] || section_mapping["skr03_category"],
          codes: get_codes_for_mapping(section_mapping)
        }

        # Process children
        if children && !children.empty?
          section[:children] = children.map do |child_name|
            child_mapping = find_mapping_for_name(section_mapping, child_name)

            if child_mapping
              child_id = find_id_for_mapping(section_mapping, child_mapping)
              {
                name: child_name,
                rsid: "guv.#{section_id}.#{child_id}",
                skr03_classification: child_mapping["skr03_classification"] || child_mapping["skr03_category"],
                codes: get_codes_for_mapping(child_mapping)
              }
            else
              {
                name: child_name,
                rsid: nil,
                skr03_classification: nil,
                codes: []
              }
            end
          end
        end

        result[section_name] = section
      else
        result[section_name] = {
          rsid: nil,
          skr03_classification: nil,
          codes: []
        }
      end
    end

    result
  end

  # Find mapping entry for a given category name
  def find_mapping_for_name(mapping, name)
    return nil unless mapping.is_a?(Hash)

    # Check if any entry has this name
    mapping.each do |key, value|
      next if key == "_meta"

      if value.is_a?(Hash)
        # Check _meta if present
        if value["_meta"] && value["_meta"]["name"] == name
          return value
        end

        # Check direct name match
        if value["name"] == name
          return value
        end
      end
    end

    nil
  end

  # Find the ID (key) for a mapping entry
  def find_id_for_mapping(mapping, target)
    return nil unless mapping.is_a?(Hash)

    mapping.each do |key, value|
      next if key == "_meta"

      if value.is_a?(Hash)
        # Check if this is the target
        if value == target
          return key
        end

        # Check _meta match
        if value["_meta"] && value == target
          return key
        end
      end
    end

    nil
  end

  # Get account codes for a mapping entry
  def get_codes_for_mapping(mapping)
    return [] unless mapping.is_a?(Hash)

    skr03_classification = mapping["skr03_classification"] || mapping["skr03_category"]
    return [] if skr03_classification.nil?

    @skr03_by_classification[skr03_classification] || []
  end

  # Build mapping from SKR03 classification name to hierarchical cid
  def build_classification_to_cid_mapping
    mapping = {}

    # Map aktiva classifications
    walk_mapping(@mapping["aktiva"], "b.aktiva", mapping)

    # Map passiva classifications
    walk_mapping(@mapping["passiva"], "b.passiva", mapping)

    # Map GuV classifications
    walk_mapping(@mapping["guv"], "guv", mapping)

    mapping
  end

  # Recursively walk mapping structure to build SKR03 classification → cid mapping
  def walk_mapping(node, path, mapping)
    return unless node.is_a?(Hash)

    node.each do |key, value|
      next if key == "_meta"

      if value.is_a?(Hash)
        # Get the SKR03 classification name for this node
        skr03_classification = nil
        if value["_meta"]
          skr03_classification = value["_meta"]["skr03_classification"] || value["_meta"]["skr03_category"]
        elsif value["skr03_classification"]
          skr03_classification = value["skr03_classification"]
        elsif value["skr03_category"]
          skr03_classification = value["skr03_category"]
        end

        # Map it to the hierarchical cid
        if skr03_classification
          full_path = "#{path}.#{key}"
          mapping[skr03_classification] = full_path
        end

        # Recurse into children
        walk_mapping(value, "#{path}.#{key}", mapping)
      end
    end
  end

  # Build mapping from SKR03 classification name to presentation rule
  def build_classification_to_rule_mapping
    mapping = {}
    return mapping unless @presentation_rules && (@presentation_rules["classifications"] || @presentation_rules["categories"])

    source = @presentation_rules["classifications"] || @presentation_rules["categories"]

    source.each do |classification_name, classification_data|
      rule = classification_data["detected_rule"]
      accounts = classification_data["accounts"] || []

      # Map each account code to its rule (via classification)
      accounts.each do |account_code|
        mapping[account_code] = rule
      end

      # Also map the classification name directly
      mapping["classification:#{classification_name}"] = rule
    end

    mapping
  end

  # Get presentation rule for an account code or classification
  def get_presentation_rule(account_code, classification_name)
    return nil unless @presentation_rules

    # First check if we have a direct account mapping
    rule = @skr03_classification_to_rule[account_code]
    return rule if rule

    # Then check if we have a classification mapping
    rule = @skr03_classification_to_rule["classification:#{classification_name}"]
    return rule if rule

    # Try to find the classification in the presentation rules
    source = @presentation_rules["classifications"] || @presentation_rules["categories"]
    if source && source[classification_name]
      return source[classification_name]["detected_rule"]
    end

    nil
  end

  # Generate skr03-accounts.csv file
  def generate_skr03_accounts_csv
    ocr_data = JSON.parse(File.read('skr03-ocr-results.json'))

    # Parse all account codes
    all_codes = []
    ocr_data.each do |row|
      classification_name = row[0]&.strip || ""
      right_column = row[1]

      next if classification_name.empty? && right_column.nil?

      items = right_column&.split(";")&.map(&:strip)
      next unless items

      account_codes = items.select { |item| item =~ /\d{4,5}/ }
      account_codes.each do |ac|
        all_codes << [ classification_name, ac ]
      end
    end

    # Parse and deduplicate
    parsed_codes = ParserTools.deduplicate_by_code(
      all_codes.map do |code_tuple|
        (classification, code_info) = code_tuple
        result = ParserTools.parse_code_string(code_info)
        result[:classification] = classification
        if result[:code] == ""
          raise "ERROR! parse_code_string failed for #{code_info.inspect}"
        end
        result
      end.select { |pc| (ParserTools::PROG_FUNC_FLAGS & pc[:flags].split(" ")).size == 0 }
    )

    # Write CSV file
    File.open("skr03-accounts.csv", "w") do |f|
      f.puts "# This file was automatically generated by contrib/build_category_json.rb"
      f.puts "# Columns: code; flags; range; cid; presentation_rule; description"
      parsed_codes.each do |pc|
        # Get hierarchical classification ID from SKR03 classification name
        classification_id = @skr03_classification_to_cid[pc[:classification]] || ""

        # Get presentation rule for this account/classification
        presentation_rule = get_presentation_rule(pc[:code], pc[:classification]) || ""

        f.puts "#{pc[:code]};#{pc[:flags]};#{pc[:range]};#{classification_id};#{presentation_rule};#{pc[:description]}"
      end
    end
  end
end

# Run the builder
if __FILE__ == $PROGRAM_NAME
  Dir.chdir(File.dirname(__FILE__))
  builder = ClassificationJsonBuilder.new
  builder.build
end
