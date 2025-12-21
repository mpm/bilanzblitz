# frozen_string_literal: true

module Contrib
  module SKR03Mapping
    module Detectors
      # Detects presentation rules for SKR03 account classifications.
      #
      # Analyzes SKR03 classification names to detect saldo-dependent accounts that can appear
      # on either side of the balance sheet depending on their debit/credit balance direction.
      #
      # Key German accounting concepts:
      # - "H-Saldo" (Haben-Saldo): Credit balance, typically appears on Passiva side
      # - "S-Saldo" (Soll-Saldo): Debit balance, typically appears on Aktiva side
      # - "oder" (or): Indicates bidirectional accounts that can switch sides based on balance
      class PresentationRuleDetector
        # Single-sided saldo patterns (not bidirectional, but indicate special handling)
        SINGLE_SALDO_PATTERNS = {
          h_saldo_only: /H-Saldo$/,
          s_saldo_only: /S-Saldo$/
        }.freeze

        # Generic "oder" pattern (needs manual classification)
        GENERIC_ODER_PATTERN = /\s+oder\s+/i

        # Detects presentation rule for a given classification name.
        #
        # @param classification_name [String] SKR03 account classification from OCR results
        # @return [Hash, nil] Detection result with :rule, :confidence, and :reason keys, or nil if no pattern detected
        #
        # @example
        #   detector = PresentationRuleDetector.new
        #   detector.detect_rule("Forderungen aus L&L H-Saldo oder Verbindlichkeiten")
        #   # => { rule: :fll_standard, confidence: :high, reason: "Matched pattern: ..." }
        #
        #   detector.detect_rule("Eigenkapital")
        #   # => nil
        def detect_rule(classification_name)
          return nil if classification_name.nil? || classification_name.empty?

          # Check for specific rule patterns
          Rules::PresentationRuleDefinitions::RULES.each do |rule_id, config|
            next unless config[:patterns]

            config[:patterns].each do |pattern|
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

        # Infers default presentation rule based on keyword matching.
        #
        # Uses simple keyword matching to infer the likely presentation rule when no
        # saldo-dependent pattern is detected. Useful for providing defaults that can
        # be manually reviewed and corrected.
        #
        # @param classification_name [String] SKR03 account classification
        # @return [Symbol, nil] Inferred rule identifier or nil if unknown
        #
        # @example
        #   detector = PresentationRuleDetector.new
        #   detector.infer_default_rule("Forderungen an Kunden")
        #   # => :asset_only
        #
        #   detector.infer_default_rule("Verbindlichkeiten aus Lieferungen")
        #   # => :liability_only
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
    end
  end
end
