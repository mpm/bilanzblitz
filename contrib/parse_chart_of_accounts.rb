#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'

# These position keys are from obvious parsing fails, they all map to the "empty" positional key.
empty_positions = [
  "---",
  "Bilanz-Posten",
  "EUR",
  "F",
  "G K",
  "G",
  "HB",
  "K",
  "R",
  "SB",
  "U"
]

bilanz_aktiva = JSON.parse(File.readlines("bilanz-aktiva.json").join("\n"))
bilanz_passiva = JSON.parse(File.readlines("bilanz-passiva.json").join("\n"))

# Check which of the balance sheet names are present in positions list.
def associate_balance_sheet_names(bdata, positions)
  all_keys = []
  bdata.keys.each do |k|
    sublist = bdata[k]
    all_keys << k
    sublist.each do |item|
      all_keys << item["name"]
      item["children"].each do |child|
        all_keys << child.gsub(/;$/, '') # remove semicolon
      end
    end
  end
  isect = (all_keys & positions.keys).sort
  puts "-- INTERSECTION of parsed positions and keys from bilanz: --"
  puts "(#{all_keys.size} keys in legal listing, #{isect.size} in intersection)"
  puts isect.join("\n")
end

positions = {}

no = 0
no = 0
ocr_data = JSON.parse(File.read("skr03-ocr-results.json"))

ocr_data.each do |row|
  no += 1
  # row is [left_column_text, right_column_text]
  # Left column is Position Description
  # Right column is Items (semicolon separated)
  
  pos_desc = row[0]&.strip
  r3 = row[1] # Right column text

  if !pos_desc || pos_desc.empty?
    # puts "Warning: seems like an empty line (#{no}): #{row.inspect}"
    # Just skip empty rows which might happen
  else

    pos_desc = "(none)" if pos_desc == "" || empty_positions.include?(pos_desc)

    pdata = positions[pos_desc] ||= { name: pos_desc, items: [] }

    items = r3&.split(";")&.map(&:strip)

    pdata[:items] += items if items
  end
end

# Use this to output a summary to check for reasonable keys (or misspellings and failed parsings):
positions.keys.sort.each { |p| puts "#{p}: #{positions[p][:items].size}" }

associate_balance_sheet_names(bilanz_aktiva.merge(bilanz_passiva), positions)
