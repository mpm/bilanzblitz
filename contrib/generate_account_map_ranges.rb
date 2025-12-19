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

# Mapping from balance sheet category names to Ruby symbols
# Handles all levels of the nested structure
BALANCE_SHEET_MAPPING = {
  # Top-level Aktiva categories
  'Anlagevermögen' => :anlagevermoegen,
  'Umlaufvermögen' => :umlaufvermoegen,

  # Anlagevermögen subcategories (Level 2)
  'Immaterielle Vermögensgegenstände' => :immaterielle_vermogensgegenstaende,
  'Sachanlagen' => :sachanlagen,
  'Finanzanlagen' => :finanzanlagen,

  # Immaterielle Vermögensgegenstände subcategories (Level 3)
  'Selbst geschaffene gewerbliche Schutzrechte und ähnliche Rechte und Werte' => :selbst_geschaffene_schutzrechte,
  'entgeltlich erworbene Konzessionen, gewerbliche Schutzrechte und ähnliche Rechte und Werte sowie Lizenzen an solchen Rechten und Werten' => :erworbene_konzessionen,
  'Geschäfts- oder Firmenwert' => :geschaefts_firmenwert,

  # Sachanlagen subcategories (Level 3)
  'Grundstücke, grundstücksgleiche Rechte und Bauten einschließlich der Bauten auf fremden Grundstücken' => :grundstuecke_bauten,
  'technische Anlagen und Maschinen' => :technische_anlagen_maschinen,
  'andere Anlagen, Betriebs- und Geschäftsausstattung' => :betriebs_geschaeftsausstattung,
  'geleistete Anzahlungen und Anlagen im Bau' => :geleistete_anzahlungen_anlagen_im_bau,

  # Finanzanlagen subcategories (Level 3)
  'Anteile an verbundenen Unternehmen' => :anteile_verbundene_unternehmen,
  'Ausleihungen an verbundene Unternehmen' => :ausleihungen_verbundene_unternehmen,
  'Beteiligungen' => :beteiligungen,
  'Ausleihungen an Unternehmen, mit denen ein Beteiligungsverhältnis besteht' => :ausleihungen_beteiligungsverhaeltnis,
  'Wertpapiere des Anlagevermögens' => :wertpapiere_anlagevermoegen,
  'sonstige Ausleihungen.' => :sonstige_ausleihungen,

  # Umlaufvermögen subcategories (Level 2)
  'Vorräte' => :vorraete,
  'Forderungen und sonstige Vermögensgegenstände' => :forderungen_sonstige_vermogensgegenstaende,
  'Wertpapiere' => :wertpapiere_umlaufvermoegen,
  'Kassenbestand, Bundesbankguthaben, Guthaben bei Kreditinstituten und Schecks' => :liquide_mittel,

  # Vorräte subcategories (Level 3)
  'Roh-, Hilfs- und Betriebsstoffe' => :roh_hilfs_betriebsstoffe,
  'unfertige Erzeugnisse, unfertige Leistungen' => :unfertige_erzeugnisse,
  'fertige Erzeugnisse und Waren' => :fertige_erzeugnisse_waren,

  # Forderungen subcategories (Level 3)
  'Forderungen aus Lieferungen und Leistungen' => :forderungen_lieferungen_leistungen,
  'Forderungen gegen verbundene Unternehmen' => :forderungen_verbundene_unternehmen,
  'Forderungen gegen Unternehmen, mit denen ein Beteiligungsverhältnis besteht' => :forderungen_beteiligungsverhaeltnis,
  'sonstige Vermögensgegenstände' => :sonstige_vermogensgegenstaende,

  # Wertpapiere subcategories (Level 3)
  'sonstige Wertpapiere' => :sonstige_wertpapiere,

  # Top-level Passiva categories
  'Eigenkapital' => :eigenkapital,
  'Rückstellungen' => :rueckstellungen,
  'Verbindlichkeiten' => :verbindlichkeiten,

  # Eigenkapital subcategories (Level 2)
  'Gezeichnetes Kapital' => :gezeichnetes_kapital,
  'Kapitalrücklage' => :kapitalruecklage,
  'Gewinnrücklagen' => :gewinnruecklagen,
  'Gewinnvortrag/Verlustvortrag' => :gewinnvortrag_verlustvortrag,
  'Jahresüberschuss/Jahresfehlbetrag' => :jahresueberschuss_jahresfehlbetrag,

  # Gewinnrücklagen subcategories (Level 3)
  'gesetzliche Rücklage' => :gesetzliche_ruecklage,
  'Rücklage für Anteile an einem herrschenden oder mehrheitlich beteiligten Unternehmen' => :ruecklage_anteile,
  'satzungsmäßige Rücklagen' => :satzungsmaessige_ruecklagen,
  'andere Gewinnrücklagen' => :andere_gewinnruecklagen,

  # Rückstellungen subcategories (Level 2)
  'Rückstellungen für Pensionen und ähnliche Verpflichtungen' => :rueckstellungen_pensionen,
  'Steuerrückstellungen' => :steuerrueckstellungen,
  'sonstige Rückstellungen' => :sonstige_rueckstellungen,

  # Verbindlichkeiten subcategories (Level 2)
  'Anleihen, davon konvertibel' => :anleihen,
  'Verbindlichkeiten gegenüber Kreditinstituten' => :verbindlichkeiten_kreditinstitute,
  'erhaltene Anzahlungen auf Bestellungen' => :erhaltene_anzahlungen,
  'Verbindlichkeiten aus Lieferungen und Leistungen' => :verbindlichkeiten_lieferungen_leistungen,
  'Verbindlichkeiten aus der Annahme gezogener Wechsel und der Ausstellung eigener Wechsel' => :verbindlichkeiten_wechsel,
  'Verbindlichkeiten gegenüber verbundenen Unternehmen' => :verbindlichkeiten_verbundene_unternehmen,
  'Verbindlichkeiten gegenüber Unternehmen, mit denen ein Beteiligungsverhältnis besteht' => :verbindlichkeiten_beteiligungsverhaeltnis,
  'sonstige Verbindlichkeiten, davon aus Steuern, davon im Rahmen der sozialen Sicherheit' => :sonstige_verbindlichkeiten
}.freeze

# Context-specific mappings for categories that appear multiple times
# Key is [parent_category, item_name] => symbol
CONTEXTUAL_MAPPING = {
  [ 'Immaterielle Vermögensgegenstände', 'geleistete Anzahlungen' ] => :geleistete_anzahlungen_immaterielle,
  [ 'Sachanlagen', 'geleistete Anzahlungen und Anlagen im Bau' ] => :geleistete_anzahlungen_anlagen_im_bau,  # Already mapped above
  [ 'Vorräte', 'geleistete Anzahlungen' ] => :geleistete_anzahlungen_vorraete,
  [ 'Finanzanlagen', 'Anteile an verbundenen Unternehmen' ] => :anteile_verbundene_unternehmen_finanzanlagen,
  [ 'Wertpapiere', 'Anteile an verbundenen Unternehmen' ] => :anteile_verbundene_unternehmen_wertpapiere
}.freeze

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
    codes = (data['codes'] || []).dup  # Make a copy to avoid mutating original data

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

# Collect nested balance sheet structure preserving hierarchy
def collect_nested_bilanz_structure(bilanz_data, mapping, contextual_mapping)
  result = {
    aktiva: {},
    passiva: {}
  }

  # Process Aktiva
  if bilanz_data['aktiva']
    bilanz_data['aktiva'].each do |section_name, section_data|
      process_nested_section(section_name, section_data, mapping, contextual_mapping, result[:aktiva], nil)
    end
  end

  # Process Passiva
  if bilanz_data['passiva']
    bilanz_data['passiva'].each do |section_name, section_data|
      process_nested_section(section_name, section_data, mapping, contextual_mapping, result[:passiva], nil)
    end
  end

  result
end

# Process a section and its children recursively
def process_nested_section(section_name, section_data, mapping, contextual_mapping, output, parent_name)
  symbol_key = mapping[section_name]
  return unless symbol_key

  # Initialize section
  output[symbol_key] = {
    name: section_name,
    codes: (section_data['codes'] || []).dup,  # Make a copy to avoid reference issues
    children: {}
  }

  # Process items (used in bilanz structure)
  if section_data['items']
    section_data['items'].each do |item|
      process_nested_item(item, mapping, contextual_mapping, output[symbol_key][:children], section_name)
    end
  end

  # Process children (used in bilanz structure)
  if section_data['children']
    section_data['children'].each do |child|
      process_nested_item(child, mapping, contextual_mapping, output[symbol_key][:children], section_name)
    end
  end
end

# Process an individual item recursively
def process_nested_item(item, mapping, contextual_mapping, output, parent_name)
  item_name = item['name']

  # Check for contextual mapping first
  symbol_key = contextual_mapping[[ parent_name, item_name ]] || mapping[item_name]

  # Skip if no mapping found
  return unless symbol_key

  output[symbol_key] = {
    name: item_name,
    codes: (item['codes'] || []).dup,  # Make a copy to avoid reference issues
    children: {}
  }

  # Recursively process children
  if item['children']
    item['children'].each do |child|
      process_nested_item(child, mapping, contextual_mapping, output[symbol_key][:children], item_name)
    end
  end

  # Also check for items
  if item['items']
    item['items'].each do |subitem|
      process_nested_item(subitem, mapping, contextual_mapping, output[symbol_key][:children], item_name)
    end
  end
end

# Pretty-print nested structure as Ruby hash
def print_nested_structure(data, indent: 0)
  space = ' ' * indent

  data.each do |key, value|
    if value.is_a?(Hash)
      if key == :aktiva || key == :passiva
        puts "#{space}#{key}: {"
        print_nested_structure(value, indent: indent + 2)
        puts "#{space}}"
        puts "#{space}," unless key == data.keys.last
      elsif key == :children
        if value.empty?
          puts "#{space}children: {}"
        else
          puts "#{space}children: {"
          print_nested_structure(value, indent: indent + 2)
          puts "#{space}}"
        end
      else
        # This is a section key
        puts "#{space}#{key}: {"
        puts "#{space}  name: #{value[:name].inspect},"
        if value[:codes].empty?
          puts "#{space}  codes: [],"
        else
          ranges = codes_to_ranges(value[:codes])
          puts "#{space}  codes: [" + ranges.map { |r| "\"#{r}\"" }.join(", ") + "],"
        end
        if value[:children].empty?
          puts "#{space}  children: {}"
        else
          print_nested_structure({ children: value[:children] }, indent: indent + 2)
        end
        puts "#{space}}" + (key == data.keys.last ? "" : ",")
      end
    end
  end
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

# Process Nested Balance Sheet Structure
puts "\n# Nested Balance Sheet Structure"
puts "-" * 80
nested_bilanz = collect_nested_bilanz_structure(bilanz_data, BALANCE_SHEET_MAPPING, CONTEXTUAL_MAPPING)

puts "NESTED_BALANCE_SHEET_CATEGORIES = {"
print_nested_structure(nested_bilanz, indent: 2)
puts "}.freeze"

puts "\n" + "=" * 80
puts "Done! Copy the output above into AccountMap service."
puts "=" * 80
