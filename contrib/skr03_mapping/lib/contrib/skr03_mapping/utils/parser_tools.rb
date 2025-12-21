# frozen_string_literal: true

module Contrib
  module SKR03Mapping
    module Utils
      # Unified parser tools for working with SKR03 account codes.
      #
      # Combines functionality from ParserTools (build_category_json.rb) and
      # AccountCodeParser (generate_presentation_rules.rb) into a single module.
      module ParserTools
        # Flags that should be treated as problematic/wrong
        PROG_FUNC_FLAGS = %w[KU V M].freeze

        # Maximum size for a range to be expanded (to avoid placeholder ranges like 10000-69999)
        MAX_RANGE_SIZE = 100

        # Known placeholder ranges to skip (Debitoren/Kreditoren ranges)
        PLACEHOLDER_RANGES = [
          /10000-69999/,  # Debitoren (customer accounts)
          /70000-99999/   # Kreditoren (vendor accounts)
        ].freeze

        # Parses an account code string from the OCR results.
        #
        # @param str [String] Account code string to parse
        # @return [Hash] Parsed components with keys: :flags, :code, :range, :description
        #
        # @example
        #   ParserTools.parse_code_string("1400-99 Bank accounts")
        #   # => { flags: "", code: "1400", range: "1400-1499", description: "Bank accounts" }
        #
        #   ParserTools.parse_code_string("KU 1200 Debtors")
        #   # => { flags: "KU", code: "1200", range: "", description: "Debtors" }
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

        # Removes duplicate account codes based on specific rules.
        #
        # When multiple entries exist for the same code, prefers:
        # 1. Entry with description over without
        # 2. Entry without range over with range
        # 3. Entry without problematic flags (KU, V, M)
        #
        # @param items [Array<Hash>] Array of parsed code hashes (from parse_code_string)
        # @return [Array<Hash>] Deduplicated array
        # @raise [RuntimeError] If deduplication logic cannot determine which entry to keep
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

        # Parses account codes from the codes column of OCR results.
        #
        # Handles various formats:
        # - Single codes: "1400 Description"
        # - Multiple codes: "1400 Desc1; 1401 Desc2"
        # - Ranges: "1400-99 Description" (expands to 1400-1499)
        # - Flags: "R 1400-99 Description" (flags are stripped)
        #
        # Skips placeholder ranges (Debitoren/Kreditoren) and ranges larger than MAX_RANGE_SIZE.
        #
        # @param codes_string [String] Semicolon-separated codes from OCR results
        # @return [Array<String>] Sorted array of unique 4-digit account codes
        #
        # @example
        #   ParserTools.parse_account_codes("1400 Bank; 1401 Cash")
        #   # => ["1400", "1401"]
        #
        #   ParserTools.parse_account_codes("R 1400-05 Bank accounts")
        #   # => ["1400", "1401", "1402", "1403", "1404", "1405"]
        #
        #   ParserTools.parse_account_codes("10000-69999")  # Placeholder range
        #   # => []
        def self.parse_account_codes(codes_string)
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
    end
  end
end
