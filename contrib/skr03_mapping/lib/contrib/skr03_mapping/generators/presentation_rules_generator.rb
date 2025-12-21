# frozen_string_literal: true

require 'json'
require 'yaml'

module Contrib
  module SKR03Mapping
    module Generators
      # Generates presentation rules mapping for SKR03 account classifications.
      #
      # Analyzes SKR03 classifications to detect saldo-dependent account patterns
      # (accounts that can appear on either side of the balance sheet depending on
      # their debit/credit balance). Generates a human-editable YAML file for manual
      # review and correction.
      #
      # Key responsibilities:
      # - Load SKR03 classifications from OCR results
      # - Use PresentationRuleDetector to identify saldo patterns
      # - Parse account codes using ParserTools
      # - Generate YAML mapping grouped by detected rules
      # - Track detection statistics (bidirectional, inferred, unknown)
      class PresentationRulesGenerator
        attr_reader :stats

        # Initializes the generator with OCR data.
        #
        # @param ocr_data_path [String] Path to skr03-ocr-results.json file
        def initialize(ocr_data_path = "skr03-ocr-results.json")
          @ocr_data_path = ocr_data_path
          @ocr_data = JSON.parse(File.read(ocr_data_path))
          @detector = Detectors::PresentationRuleDetector.new
          @stats = {
            total_classifications: 0,
            bidirectional_detected: 0,
            single_saldo_detected: 0,
            generic_oder_detected: 0,
            default_inferred: 0,
            unknown: 0
          }
        end

        # Generates the presentation rules data structure.
        #
        # @return [Array<Hash>] Array of classification data with detected rules
        def generate
          process_classifications
        end

        # Writes presentation rules to YAML file.
        #
        # @param output_path [String] Path to output YAML file
        # @param classifications [Array<Hash>] Classification data from generate()
        def write_yaml(output_path, classifications)
          # Group by detected rule
          by_rule = classifications.group_by { |c| c[:detected_rule] }

          # Generate YAML output
          output = generate_yaml_output(by_rule)

          # Write file
          File.open(output_path, "w") do |f|
            f.write output
          end
        end

        # Prints generation statistics to stdout.
        def print_stats
          puts
          puts "=" * 80
          puts "Presentation Rules Statistics"
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
        end

        private

        def process_classifications
          classifications = []

          @ocr_data.each do |row|
            classification_name = row[0]&.strip
            codes_string = row[1]&.strip

            next if classification_name.nil? || classification_name.empty?

            @stats[:total_classifications] += 1

            # Parse account codes using ParserTools
            account_codes = Utils::ParserTools.parse_account_codes(codes_string || "")

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
            # Generated by: Contrib::SKR03Mapping::Generators::PresentationRulesGenerator
            # Review and fix before running bin/skr03_mapper build-json
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
            # After review, run: bin/skr03_mapper build-json
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
      end
    end
  end
end
