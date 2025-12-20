#!/usr/bin/env ruby
# frozen_string_literal: true

#
# Category JSON Builder
# =====================
#
# Builds bilanz-with-categories.json and guv-with-categories.json
# from validated category-mapping.yml and skr03-ocr-results.json
#
# Input Files:
# - category-mapping.yml: Validated intermediate mapping (manually edited)
# - skr03-ocr-results.json: SKR03 categories with account codes
# - bilanz-aktiva.json: Balance sheet structure (for structure reference)
# - bilanz-passiva.json: Balance sheet structure (for structure reference)
# - guv.json: GuV structure (for structure reference)
#
# Output Files:
# - bilanz-with-categories.json: Balance sheet with category IDs and codes
# - guv-with-categories.json: GuV with category IDs and codes

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
class CategoryJsonBuilder
  def initialize
    @mapping = YAML.load_file('category-mapping.yml')
    @bilanz_aktiva = JSON.parse(File.read('bilanz-aktiva.json'))
    @bilanz_passiva = JSON.parse(File.read('bilanz-passiva.json'))
    @guv = JSON.parse(File.read('guv.json'))

    # Build SKR03 category → account codes mapping
    @skr03_by_category = build_skr03_index
  end

  def build
    puts "=" * 80
    puts "Building Category JSON Files from Mapping"
    puts "=" * 80
    puts

    # Build bilanz-with-categories.json
    bilanz_output = {
      aktiva: build_balance_sheet_side(@bilanz_aktiva, @mapping["aktiva"], "aktiva"),
      passiva: build_balance_sheet_side(@bilanz_passiva, @mapping["passiva"], "passiva")
    }

    File.open("bilanz-with-categories.json", "w") do |f|
      f.write JSON.pretty_generate(bilanz_output)
    end

    puts "✓ Generated bilanz-with-categories.json"

    # Build guv-with-categories.json
    guv_output = build_guv_structure
    File.open("guv-with-categories.json", "w") do |f|
      f.write JSON.pretty_generate(guv_output)
    end

    puts "✓ Generated guv-with-categories.json"
    puts
    puts "Done! Final JSON files have been generated."
    puts
  end

  private

  # Build index: SKR03 category name → account codes
  def build_skr03_index
    ocr_data = JSON.parse(File.read('skr03-ocr-results.json'))

    # Parse all account codes
    all_codes = []
    ocr_data.each do |row|
      category_name = row[0]&.strip || ""
      right_column = row[1]

      next if category_name.empty? && right_column.nil?

      items = right_column&.split(";")&.map(&:strip)
      next unless items

      account_codes = items.select { |item| item =~ /\d{4,5}/ }
      account_codes.each do |ac|
        all_codes << [ category_name, ac ]
      end
    end

    # Parse and deduplicate
    parsed_codes = ParserTools.deduplicate_by_code(
      all_codes.map do |code_tuple|
        (category, code_info) = code_tuple
        result = ParserTools.parse_code_string(code_info)
        result[:category] = category
        if result[:code] == ""
          raise "ERROR! parse_code_string failed for #{code_info.inspect}"
        end
        result
      end.select { |pc| (ParserTools::PROG_FUNC_FLAGS & pc[:flags].split(" ")).size == 0 }
    )

    # Build index
    index = Hash.new { |h, k| h[k] = [] }
    parsed_codes.each do |pc|
      category = pc[:category]
      code = pc[:code]
      index[category] << code if category && code
    end

    # Sort codes
    index.each { |_, codes| codes.sort! }

    index
  end

  # Build balance sheet side (aktiva or passiva)
  def build_balance_sheet_side(structure, mapping, side)
    result = {}

    structure.each do |section_name, section_data|
      # Find mapping for this section
      section_mapping = find_mapping_for_name(mapping, section_name)

      if section_mapping
        section_id = find_id_for_mapping(mapping, section_mapping)
        result[section_name] = build_balance_section(section_name, section_data, section_mapping, section_id, side)
      else
        # No mapping found - create empty structure
        result[section_name] = {
          cid: nil,
          matched_category: nil,
          codes: []
        }
      end
    end

    result
  end

  def build_balance_section(name, data, mapping, path_prefix, side)
    meta = mapping["_meta"] if mapping.is_a?(Hash)

    section = {
      cid: path_prefix,
      matched_category: meta ? meta["skr03_category"] : mapping["skr03_category"],
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

    item_obj = {
      name: item["name"],
      cid: path_prefix,
      matched_category: meta ? meta["skr03_category"] : mapping["skr03_category"],
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
            cid: "#{path_prefix}.#{child_id}",
            matched_category: child_mapping["skr03_category"],
            codes: get_codes_for_mapping(child_mapping)
          }
        else
          {
            name: clean_child_name,
            cid: nil,
            matched_category: nil,
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
            cid: "#{path_prefix}.#{child_id}",
            matched_category: child_mapping["skr03_category"],
            codes: get_codes_for_mapping(child_mapping)
          }
        else
          {
            name: clean_child_name,
            cid: nil,
            matched_category: nil,
            codes: []
          }
        end
      end
    }
  end

  def build_empty_item(item)
    {
      name: item["name"] || "",
      cid: nil,
      matched_category: nil,
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
          cid: "guv.#{section_id}",
          matched_category: section_mapping["skr03_category"],
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
                cid: "guv.#{section_id}.#{child_id}",
                matched_category: child_mapping["skr03_category"],
                codes: get_codes_for_mapping(child_mapping)
              }
            else
              {
                name: child_name,
                cid: nil,
                matched_category: nil,
                codes: []
              }
            end
          end
        end

        result[section_name] = section
      else
        result[section_name] = {
          cid: nil,
          matched_category: nil,
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

    skr03_category = mapping["skr03_category"]
    return [] if skr03_category.nil?

    @skr03_by_category[skr03_category] || []
  end
end

# Run the builder
if __FILE__ == $PROGRAM_NAME
  Dir.chdir(File.dirname(__FILE__))
  builder = CategoryJsonBuilder.new
  builder.build
end
