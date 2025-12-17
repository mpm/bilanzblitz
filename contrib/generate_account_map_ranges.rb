#!/usr/bin/env ruby
# frozen_string_literal: true

# Helper script to generate account ranges for AccountMap from JSON files
# Reads bilanz-with-categories.json and guv-with-categories.json
# Outputs account ranges mapped to AccountMap symbol keys

require 'json'

# Load JSON files
bilanz_data = JSON.parse(File.read('contrib/bilanz-with-categories.json'))
guv_data = JSON.parse(File.read('contrib/guv-with-categories.json'))

# Mapping from JSON section names to AccountMap symbol keys
GUV_MAPPING = {
  'Umsatzerlöse' => :umsatzerloese,
  'Erhöhung oder Verminderung des Bestands an fertigen und unfertigen Erzeugnissen' => :bestandsveraenderungen,
  'andere aktivierte Eigenleistungen' => :aktivierte_eigenleistungen,
  'sonstige betriebliche Erträge' => :sonstige_betriebliche_ertraege,
  'Aufwendungen für Roh-, Hilfs- und Betriebsstoffe und für bezogene Waren' => :materialaufwand_roh_hilfs_betriebsstoffe,
  'Aufwendungen für bezogene Leistungen' => :materialaufwand_bezogene_leistungen,
  'Löhne und Gehälter' => :personalaufwand_loehne_gehaelter,
  'soziale Abgaben und Aufwendungen für Altersversorgung und für Unterstützung, davon für Altersversorgung' => :personalaufwand_soziale_abgaben,
  # Note: "Abschreibungen" parent section codes are added to abschreibungen_anlagevermoegen
  'auf immaterielle Vermögensgegenstände des Anlagevermögens und Sachanlagen' => :abschreibungen_anlagevermoegen,
  'auf Vermögensgegenstände des Umlaufvermögens, soweit diese die in der Kapitalgesellschaft üblichen Abschreibungen überschreiten' => :abschreibungen_umlaufvermoegen,
  'sonstige betriebliche Aufwendungen' => :sonstige_betriebliche_aufwendungen,
  'Erträge aus Beteiligungen, davon aus verbundenen Unternehmen' => :ertraege_beteiligungen,
  'Erträge aus anderen Wertpapieren und Ausleihungen des Finanzanlagevermögens, davon aus verbundenen Unternehmen' => :ertraege_wertpapiere,
  'sonstige Zinsen und ähnliche Erträge, davon aus verbundenen Unternehmen' => :sonstige_zinsen_ertraege,
  'Abschreibungen auf Finanzanlagen und auf Wertpapiere des Umlaufvermögens' => :abschreibungen_finanzanlagen,
  'Zinsen und ähnliche Aufwendungen, davon an verbundene Unternehmen' => :zinsen_aufwendungen,
  'Steuern vom Einkommen und vom Ertrag' => :steuern_einkommen_ertrag,
  'sonstige Steuern' => :sonstige_steuern
}

# Sections that should receive parent-level codes (when parent has codes but only children are mapped)
PARENT_CODE_RECIPIENTS = {
  'Abschreibungen' => :abschreibungen_anlagevermoegen
}

# Collect all codes for each GuV section
def collect_guv_codes(guv_data, mapping, parent_recipients)
  result = {}

  guv_data.each do |section_name, section_data|
    # Get the symbol key for this section
    symbol_key = mapping[section_name]

    if symbol_key
      # Collect codes from this section
      codes = section_data['codes'] || []

      # If section has children, collect codes from them
      if section_data['children']
        section_data['children'].each do |child|
          child_name = child['name']
          child_symbol = mapping[child_name]

          if child_symbol
            # Store child codes separately
            result[child_symbol] ||= []
            result[child_symbol].concat(child['codes'] || [])
          else
            # If no specific mapping for child, add to parent
            codes.concat(child['codes'] || [])
          end
        end
      end

      result[symbol_key] ||= []
      result[symbol_key].concat(codes)
    elsif parent_recipients[section_name]
      # This section is not directly mapped, but its parent-level codes should go to a specific target
      recipient_key = parent_recipients[section_name]
      result[recipient_key] ||= []
      result[recipient_key].concat(section_data['codes'] || [])

      # Still process children normally
      if section_data['children']
        section_data['children'].each do |child|
          child_name = child['name']
          child_symbol = mapping[child_name]

          if child_symbol
            result[child_symbol] ||= []
            result[child_symbol].concat(child['codes'] || [])
          end
        end
      end
    end
  end

  result
end

# Collect all codes for each balance sheet category
def collect_bilanz_codes(bilanz_data)
  result = {
    anlagevermoegen: [],
    umlaufvermoegen: [],
    eigenkapital: [],
    fremdkapital: []
  }

  # Helper to recursively collect codes from nested structure
  def collect_codes_recursive(data)
    codes = data['codes'] || []

    if data['items']
      data['items'].each do |item|
        codes.concat(collect_codes_recursive(item))
      end
    end

    if data['children']
      data['children'].each do |child|
        codes.concat(collect_codes_recursive(child))
      end
    end

    codes
  end

  # Aktiva
  if bilanz_data['aktiva']
    if bilanz_data['aktiva']['Anlagevermögen']
      result[:anlagevermoegen] = collect_codes_recursive(bilanz_data['aktiva']['Anlagevermögen'])
    end

    if bilanz_data['aktiva']['Umlaufvermögen']
      result[:umlaufvermoegen] = collect_codes_recursive(bilanz_data['aktiva']['Umlaufvermögen'])
    end
  end

  # Passiva
  if bilanz_data['passiva']
    if bilanz_data['passiva']['Eigenkapital']
      result[:eigenkapital] = collect_codes_recursive(bilanz_data['passiva']['Eigenkapital'])
    end

    # Fremdkapital includes Rückstellungen and Verbindlichkeiten
    fremdkapital_codes = []
    if bilanz_data['passiva']['Rückstellungen']
      fremdkapital_codes.concat(collect_codes_recursive(bilanz_data['passiva']['Rückstellungen']))
    end
    if bilanz_data['passiva']['Verbindlichkeiten']
      fremdkapital_codes.concat(collect_codes_recursive(bilanz_data['passiva']['Verbindlichkeiten']))
    end
    result[:fremdkapital] = fremdkapital_codes
  end

  result
end

# Convert list of account codes to ranges
def codes_to_ranges(codes)
  # Remove duplicates and sort
  codes = codes.uniq.sort

  return [] if codes.empty?

  ranges = []
  range_start = codes.first
  range_end = codes.first

  codes.each_with_index do |code, index|
    next if index == 0

    prev_code = codes[index - 1]

    # Check if this code continues the range
    if code.to_i == prev_code.to_i + 1
      range_end = code
    else
      # End current range and start new one
      if range_start == range_end
        ranges << range_start
      else
        ranges << "#{range_start}-#{range_end}"
      end

      range_start = code
      range_end = code
    end
  end

  # Add final range
  if range_start == range_end
    ranges << range_start
  else
    ranges << "#{range_start}-#{range_end}"
  end

  ranges
end

# Main execution
puts "=" * 80
puts "Generating AccountMap ranges from JSON files"
puts "=" * 80

# Process GuV sections
puts "\n# GuV Sections"
puts "-" * 80
guv_codes = collect_guv_codes(guv_data, GUV_MAPPING, PARENT_CODE_RECIPIENTS)

guv_codes.each do |symbol, codes|
  ranges = codes_to_ranges(codes)
  puts "#{symbol}:"
  if ranges.empty?
    puts "  []"
  else
    puts "  [" + ranges.map { |r| "\"#{r}\"" }.join(", ") + "]"
  end
  puts
end

# Process Balance Sheet categories
puts "\n# Balance Sheet Categories"
puts "-" * 80
bilanz_codes = collect_bilanz_codes(bilanz_data)

bilanz_codes.each do |symbol, codes|
  ranges = codes_to_ranges(codes)
  puts "#{symbol}:"
  if ranges.empty?
    puts "  []"
  else
    puts "  [" + ranges.map { |r| "\"#{r}\"" }.join(", ") + "]"
  end
  puts
end

puts "=" * 80
puts "Done! Copy the output above into AccountMap service."
puts "=" * 80
