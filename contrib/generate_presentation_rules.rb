#!/usr/bin/env ruby
# frozen_string_literal: true

#
# Presentation Rules Generator for SKR03 Accounts
# ================================================
#
# This script analyzes SKR03 OCR results to detect saldo-dependent classifications
# and generates a YAML mapping file for manual review.
#
# Saldo-dependent classifications have patterns like:
# - "Forderungen aus L&L H-Saldo oder sonstige Verbindlichkeiten S-Saldo"
# - "Verbindlichkeiten aus L&L S-Saldo oder sonstige Vermögensgegenstände H-Saldo"
# - "X oder Y" (without explicit saldo direction)
#
# Input Files:
# - skr03-ocr-results.json: OCR results from SKR03 PDF
#
# Output Files:
# - skr03-presentation-rules.yml: Mapping of classifications to presentation rules
#

require 'json'
require 'yaml'

# Presentation rule detector
class PresentationRuleDetector
  # Known rule patterns
  RULE_PATTERNS = {
    # Explicit saldo patterns with "oder" (bidirectional)
    fll_standard: [
      /Forderungen.*L.*L.*H-Saldo.*oder.*Verbindlichkeit/i,
      /Forderungen.*Lieferung.*Leistung.*oder.*Verbindlichkeit/i
    ],
    vll_standard: [
      /Verbindlichkeit.*L.*L.*S-Saldo.*oder.*Vermögensgegenst/i,
      /Verbindlichkeit.*Lieferung.*Leistung.*oder.*Vermögensgegenst/i,
      /Verbindlichkeit.*Lieferung.*Leistung.*oder.*Forderung/i
    ],
    bank_bidirectional: [
      /Kassenbestand.*oder.*Verbindlichkeit.*Kreditinstitut/i,
      /Guthaben.*Kreditinstitut.*oder.*Verbindlichkeit/i,
      /Bank.*oder.*Verbindlichkeit.*Kreditinstitut/i
    ],
    tax_standard: [
      /Steuer.*oder.*Steuer/i,
      /Steuerforderung.*oder.*Steuerverbindlichkeit/i
    ],
    receivable_affiliated: [
      /Forderung.*verbunden.*Unternehmen.*oder.*Verbindlichkeit.*verbunden/i,
      /Forderung.*verbund.*oder.*Verbindlichkeit.*verbund/i
    ],
    payable_affiliated: [
      /Verbindlichkeit.*verbunden.*Unternehmen.*oder.*Forderung.*verbunden/i,
      /Verbindlichkeit.*verbund.*oder.*Forderung.*verbund/i
    ],
    receivable_beteiligung: [
      /Forderung.*Beteiligung.*oder.*Verbindlichkeit.*Beteiligung/i
    ],
    payable_beteiligung: [
      /Verbindlichkeit.*Beteiligung.*oder.*Forderung.*Beteiligung/i
    ],
    sonstige_bidirectional: [
      /Sonstige Vermögensgegenstände.*oder.*sonstige Verbindlichkeit/i,
      /Sonstige Vermögensgegenst.*oder.*Verbindlichkeit/i
    ]
  }.freeze

  # Single-sided saldo patterns (not bidirectional, but indicate special handling)
  SINGLE_SALDO_PATTERNS = {
    h_saldo_only: /H-Saldo$/,
    s_saldo_only: /S-Saldo$/
  }.freeze

  # Generic "oder" pattern (needs manual classification)
  GENERIC_ODER_PATTERN = /\s+oder\s+/i

  def detect_rule(classification_name)
    return nil if classification_name.nil? || classification_name.empty?

    # Check for specific rule patterns
    RULE_PATTERNS.each do |rule_id, patterns|
      patterns.each do |pattern|
        if classification_name.match?(pattern)
          return {
            rule: rule_id,
            confidence: :high,
            reason: "Matched pattern: #{pattern.source}"
          }
        end
      end
    end

    # Check for single-sided saldo patterns
    SINGLE_SALDO_PATTERNS.each do |saldo_type, pattern|
      if classification_name.match?(pattern)
        # H-Saldo at end typically means "Wertberichtigung" or credit-balance account
        # S-Saldo at end typically means debit-balance constraint
        inferred_rule = case saldo_type
        when :h_saldo_only
                          classification_name.include?("Forderung") ? :fll_standard : :liability_only
        when :s_saldo_only
                          classification_name.include?("Verbindlichkeit") ? :vll_standard : :asset_only
        end
        return {
          rule: inferred_rule,
          confidence: :medium,
          reason: "Single saldo pattern: #{saldo_type}"
        }
      end
    end

    # Check for generic "oder" pattern (needs manual review)
    if classification_name.match?(GENERIC_ODER_PATTERN)
      return {
        rule: :needs_review,
        confidence: :low,
        reason: "Contains 'oder' but no specific pattern matched"
      }
    end

    # No saldo-dependent pattern detected
    nil
  end

  def infer_default_rule(classification_name)
    classification_lower = classification_name.downcase

    # Check for known classification types to infer default rule
    if classification_lower.include?("forderung") && !classification_lower.include?("oder")
      :asset_only
    elsif classification_lower.include?("verbindlichkeit") && !classification_lower.include?("oder")
      :liability_only
    elsif classification_lower.include?("rückstellung")
      :liability_only
    elsif classification_lower.include?("eigenkapital") || classification_lower.include?("kapital")
      :equity_only
    elsif classification_lower.include?("aufwand") || classification_lower.include?("aufwendung")
      :pnl_only
    elsif classification_lower.include?("ertrag") || classification_lower.include?("erlös")
      :pnl_only
    elsif classification_lower.include?("anlagevermögen") || classification_lower.include?("sachanlagen")
      :asset_only
    elsif classification_lower.include?("vorräte") || classification_lower.include?("vorrat")
      :asset_only
    elsif classification_lower.include?("kasse") || classification_lower.include?("bank") || classification_lower.include?("guthaben")
      # Bank could be bidirectional, but default to asset_only unless pattern detected
      :asset_only
    else
      nil # Unknown - needs manual review
    end
  end
end

# Parses account codes from OCR result strings
class AccountCodeParser
  # Maximum size for a range to be expanded (to avoid placeholder ranges like 10000-69999)
  MAX_RANGE_SIZE = 100

  # Known placeholder ranges to skip (Debitoren/Kreditoren ranges)
  PLACEHOLDER_RANGES = [
    /10000-69999/,  # Debitoren (customer accounts)
    /70000-99999/   # Kreditoren (vendor accounts)
  ].freeze

  # Parse account codes from the right column of OCR results
  # Format: "1400 Description; 1401 Description; R 1402-1499"
  def self.parse(codes_string)
    return [] if codes_string.nil? || codes_string.empty?

    # Skip known placeholder ranges
    PLACEHOLDER_RANGES.each do |pattern|
      return [] if codes_string.match?(pattern)
    end

    codes = []

    # Split by semicolon
    parts = codes_string.split(";").map(&:strip)

    parts.each do |part|
      # Remove leading flags like "AV", "F", "S", "R"
      clean_part = part.gsub(/^[A-Z]+\s+/, "")

      # Extract account code (4-digit number at start)
      if clean_part =~ /^(\d{4})/
        codes << $1
      end

      # Check for range notation (e.g., "1402-1499" or "1402-99")
      if clean_part =~ /(\d{4})-(\d+)/
        start_code = $1
        end_suffix = $2

        # If end is just 2 digits, it's a suffix (e.g., "1400-99" means 1400-1499)
        if end_suffix.length <= 2
          end_code = start_code[0, 4 - end_suffix.length] + end_suffix
        else
          end_code = end_suffix
        end

        range_size = end_code.to_i - start_code.to_i + 1

        # Skip ranges that are too large (likely placeholders)
        if range_size > MAX_RANGE_SIZE
          # Don't expand, just skip this range
          next
        end

        # Add all codes in range
        (start_code.to_i..end_code.to_i).each do |code|
          codes << code.to_s.rjust(4, "0")
        end
      end
    end

    codes.uniq.sort
  end
end

# Main generator
class PresentationRulesGenerator
  def initialize
    @ocr_data = JSON.parse(File.read("skr03-ocr-results.json"))
    @detector = PresentationRuleDetector.new
    @stats = {
      total_classifications: 0,
      bidirectional_detected: 0,
      single_saldo_detected: 0,
      generic_oder_detected: 0,
      default_inferred: 0,
      unknown: 0
    }
  end

  def generate
    puts "=" * 80
    puts "Presentation Rules Generator - SKR03 Saldo Detection"
    puts "=" * 80
    puts

    # Process all classifications
    classifications = process_classifications

    # Group by detected rule
    by_rule = classifications.group_by { |c| c[:detected_rule] }

    # Generate YAML output
    output = generate_yaml_output(by_rule)

    # Write file
    File.open("skr03-presentation-rules.yml", "w") do |f|
      f.write output
    end

    print_statistics
  end

  private

  def process_classifications
    classifications = []

    @ocr_data.each do |row|
      classification_name = row[0]&.strip
      codes_string = row[1]&.strip

      next if classification_name.nil? || classification_name.empty?

      @stats[:total_classifications] += 1

      # Parse account codes
      account_codes = AccountCodeParser.parse(codes_string)

      # Detect saldo pattern
      detection = @detector.detect_rule(classification_name)

      if detection
        case detection[:confidence]
        when :high
          @stats[:bidirectional_detected] += 1
        when :medium
          @stats[:single_saldo_detected] += 1
        when :low
          @stats[:generic_oder_detected] += 1
        end

        classifications << {
          classification: classification_name,
          detected_rule: detection[:rule],
          confidence: detection[:confidence],
          reason: detection[:reason],
          accounts: account_codes,
          status: detection[:confidence] == :high ? "auto" : "needs_review"
        }
      else
        # Try to infer default rule
        default_rule = @detector.infer_default_rule(classification_name)

        if default_rule
          @stats[:default_inferred] += 1
          classifications << {
            classification: classification_name,
            detected_rule: default_rule,
            confidence: :inferred,
            reason: "Inferred from classification name",
            accounts: account_codes,
            status: "inferred"
          }
        else
          @stats[:unknown] += 1
          classifications << {
            classification: classification_name,
            detected_rule: :unknown,
            confidence: :none,
            reason: "No pattern matched",
            accounts: account_codes,
            status: "unknown"
          }
        end
      end
    end

    classifications
  end

  def generate_yaml_output(by_rule)
    output = <<~HEADER
      # Presentation Rules Mapping for SKR03 Accounts
      # ==============================================
      #
      # This file maps SKR03 classifications to presentation rules (Bilanzierungsregeln).
      # Presentation rules determine where an account balance appears on the balance
      # sheet based on the saldo direction (debit or credit).
      #
      # Generated by: generate_presentation_rules.rb
      # Review and fix before running build_category_json.rb
      #
      # Available Rules:
      #   - asset_only: Always on Aktiva side
      #   - liability_only: Always on Passiva side
      #   - equity_only: Always in Eigenkapital
      #   - pnl_only: P&L accounts (never on balance sheet)
      #   - fll_standard: Forderungen L&L (debit->Aktiva, credit->Sonstige Verbindlichkeiten)
      #   - vll_standard: Verbindlichkeiten L&L (credit->Passiva, debit->Sonstige Forderungen)
      #   - bank_bidirectional: Bank (debit->Liquide Mittel, credit->Verbindl. ggü. Kreditinstituten)
      #   - tax_standard: Tax (debit->Forderung, credit->Verbindlichkeit)
      #   - receivable_affiliated: Forderungen gg. verbundene (bidirectional)
      #   - payable_affiliated: Verbindlichkeiten gg. verbundene (bidirectional)
      #
      # Status Values:
      #   - auto: Automatically detected with high confidence
      #   - needs_review: Detected but needs manual verification
      #   - inferred: Inferred from classification name (default rule)
      #   - manual: Manually specified/corrected
      #   - unknown: No pattern matched (needs manual assignment)
      #
      # After review, run: ruby build_category_json.rb
      #

    HEADER

    yaml_data = {
      "rules" => generate_rules_section,
      "classifications" => {}
    }

    # Sort rules for predictable output
    rule_order = [
      :fll_standard, :vll_standard, :bank_bidirectional, :tax_standard,
      :receivable_affiliated, :payable_affiliated, :receivable_beteiligung, :payable_beteiligung,
      :sonstige_bidirectional, :needs_review, :asset_only, :liability_only,
      :equity_only, :pnl_only, :unknown
    ]

    rule_order.each do |rule|
      next unless by_rule[rule]

      by_rule[rule].each do |cat_data|
        yaml_data["classifications"][cat_data[:classification]] = {
          "detected_rule" => cat_data[:detected_rule].to_s,
          "confidence" => cat_data[:confidence].to_s,
          "reason" => cat_data[:reason],
          "accounts" => cat_data[:accounts],
          "status" => cat_data[:status]
        }
      end
    end

    # Handle any remaining rules not in the order list
    by_rule.each do |rule, cats|
      next if rule_order.include?(rule)

      cats.each do |cat_data|
        yaml_data["classifications"][cat_data[:classification]] = {
          "detected_rule" => cat_data[:detected_rule].to_s,
          "confidence" => cat_data[:confidence].to_s,
          "reason" => cat_data[:reason],
          "accounts" => cat_data[:accounts],
          "status" => cat_data[:status]
        }
      end
    end

    output + YAML.dump(yaml_data)
  end

  def generate_rules_section
    {
      "fll_standard" => {
        "name" => "Forderungen L&L Standard",
        "description" => "S-Saldo: Forderungen aus L&L | H-Saldo: Sonstige Verbindlichkeiten",
        "debit_rsid" => "b.aktiva.umlaufvermoegen.forderungen_und_sonstige_vermoegensgegenstaende.forderungen_aus_lieferungen_und_leistungen",
        "credit_rsid" => "b.passiva.verbindlichkeiten.sonstige_verbindlichkeiten_davon_aus_steuern_davon_im_rahmen"
      },
      "vll_standard" => {
        "name" => "Verbindlichkeiten L&L Standard",
        "description" => "H-Saldo: Verbindlichkeiten aus L&L | S-Saldo: Sonstige Vermögensgegenstände",
        "debit_rsid" => "b.aktiva.umlaufvermoegen.forderungen_und_sonstige_vermoegensgegenstaende.sonstige_vermoegensgegenstaende",
        "credit_rsid" => "b.passiva.verbindlichkeiten.verbindlichkeiten_aus_lieferungen_und_leistungen"
      },
      "bank_bidirectional" => {
        "name" => "Bankkonten bidirektional",
        "description" => "S-Saldo: Liquide Mittel | H-Saldo: Verbindlichkeiten ggü. Kreditinstituten",
        "debit_rsid" => "b.aktiva.umlaufvermoegen.kassenbestand_bundesbankguthaben_guthaben_bei_kreditinstitut",
        "credit_rsid" => "b.passiva.verbindlichkeiten.verbindlichkeiten_gegenueber_kreditinstituten"
      },
      "tax_standard" => {
        "name" => "Steuerforderung/-schuld",
        "description" => "S-Saldo: Sonstige Vermögensgegenstände | H-Saldo: Sonstige Verbindlichkeiten",
        "debit_rsid" => "b.aktiva.umlaufvermoegen.forderungen_und_sonstige_vermoegensgegenstaende.sonstige_vermoegensgegenstaende",
        "credit_rsid" => "b.passiva.verbindlichkeiten.sonstige_verbindlichkeiten_davon_aus_steuern_davon_im_rahmen"
      },
      "receivable_affiliated" => {
        "name" => "Forderungen gg. verbundene Unternehmen",
        "description" => "S-Saldo: Forderungen gg. verbundene | H-Saldo: Verbindlichkeiten gg. verbundene",
        "debit_rsid" => "b.aktiva.umlaufvermoegen.forderungen_und_sonstige_vermoegensgegenstaende.forderungen_gegen_verbundene_unternehmen",
        "credit_rsid" => "b.passiva.verbindlichkeiten.verbindlichkeiten_gegenueber_verbundenen_unternehmen"
      },
      "payable_affiliated" => {
        "name" => "Verbindlichkeiten gg. verbundene Unternehmen",
        "description" => "H-Saldo: Verbindlichkeiten gg. verbundene | S-Saldo: Forderungen gg. verbundene",
        "debit_rsid" => "b.aktiva.umlaufvermoegen.forderungen_und_sonstige_vermoegensgegenstaende.forderungen_gegen_verbundene_unternehmen",
        "credit_rsid" => "b.passiva.verbindlichkeiten.verbindlichkeiten_gegenueber_verbundenen_unternehmen"
      },
      "asset_only" => {
        "name" => "Nur Aktiva",
        "description" => "Immer auf der Aktivseite (z.B. Anlagevermögen, Vorräte)",
        "debit_rsid" => nil,
        "credit_rsid" => nil
      },
      "liability_only" => {
        "name" => "Nur Passiva",
        "description" => "Immer auf der Passivseite (z.B. Rückstellungen, Verbindlichkeiten)",
        "debit_rsid" => nil,
        "credit_rsid" => nil
      },
      "equity_only" => {
        "name" => "Nur Eigenkapital",
        "description" => "Immer im Eigenkapital",
        "debit_rsid" => nil,
        "credit_rsid" => nil
      },
      "pnl_only" => {
        "name" => "Nur GuV",
        "description" => "Aufwands- und Ertragskonten - nicht in der Bilanz",
        "debit_rsid" => nil,
        "credit_rsid" => nil
      }
    }
  end

  def print_statistics
    puts
    puts "=" * 80
    puts "Presentation Rules Generated: skr03-presentation-rules.yml"
    puts "=" * 80
    puts
    puts "Statistics:"
    puts "  Total classifications analyzed: #{@stats[:total_classifications]}"
    puts "  Bidirectional rules detected (high confidence): #{@stats[:bidirectional_detected]}"
    puts "  Single-saldo patterns detected: #{@stats[:single_saldo_detected]}"
    puts "  Generic 'oder' patterns (needs review): #{@stats[:generic_oder_detected]}"
    puts "  Default rules inferred: #{@stats[:default_inferred]}"
    puts "  Unknown (needs manual assignment): #{@stats[:unknown]}"
    puts
    puts "Next steps:"
    puts "  1. Review skr03-presentation-rules.yml"
    puts "  2. Verify/fix detected rules, especially 'needs_review' entries"
    puts "  3. Assign rules to 'unknown' classifications"
    puts "  4. Run: ruby build_category_json.rb"
    puts
  end
end

# Run the generator
if __FILE__ == $PROGRAM_NAME
  Dir.chdir(File.dirname(__FILE__))
  generator = PresentationRulesGenerator.new
  generator.generate
end
