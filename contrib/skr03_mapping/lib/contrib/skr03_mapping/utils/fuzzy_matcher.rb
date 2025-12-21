# frozen_string_literal: true

module Contrib
  module SKR03Mapping
    module Utils
      # Fuzzy matching utility for matching official HGB category names with SKR03 classifications.
      #
      # Uses case-insensitive prefix matching, prioritizing longer overlaps and exact matches.
      # This helps automatically map German accounting categories from the official HGB structure
      # to the parsed SKR03 account classifications.
      module FuzzyMatcher
        # Performs fuzzy matching between official HGB category names and parsed SKR03 account classification names.
        # Uses case-insensitive prefix matching, prioritizing longer overlaps and exact matches.
        #
        # @param official_names [Array<String>] Official category names from GuV/Bilanz structures
        # @param classification_names [Array<String>] Parsed classification names from OCR results
        # @return [Array<Hash, Array>] Tuple of [matched_hash, unmatched_classifications]
        #   - matched_hash: Maps official names to match results (:original_classification, :partial, :no_match)
        #   - unmatched_classifications: Array of classification names that weren't matched
        def self.fuzzy_match(official_names, classification_names)
          matches = []

          official_names.each_with_index do |official, oi|
            official_down = official.downcase

            classification_names.each_with_index do |classification, ci|
              classification_down = classification.downcase

              # Determine shorter / longer string (case-insensitive)
              if official_down.length <= classification_down.length
                shorter_down = official_down
                longer_down  = classification_down
                shorter_orig = official
              else
                shorter_down = classification_down
                longer_down  = official_down
                shorter_orig = classification
              end

              # Case-insensitive prefix match
              next unless longer_down.start_with?(shorter_down)

              matches << {
                official_index: oi,
                classification_index: ci,
                official: official,
                classification: classification,
                overlap: shorter_down.length,
                exact: official_down == classification_down,
                matched_part: shorter_orig[0, shorter_down.length]
              }
            end
          end

          # Sort matches by best first
          matches.sort_by! do |m|
            [
              -m[:overlap],          # longer overlap first
              m[:exact] ? 0 : 1      # exact matches first
            ]
          end

          used_officials  = {}
          used_classifications = {}
          result = {}

          matches.each do |m|
            oi = m[:official_index]
            ci = m[:classification_index]

            next if used_officials[oi] || used_classifications[ci]

            used_officials[oi]  = true
            used_classifications[ci] = true

            result[m[:official]] = {
              match: m[:matched_part],
              original_classification: m[:classification],
              partial: !m[:exact]
            }
          end

          # Officials with no match
          official_names.each_with_index do |official, oi|
            result[official] ||= { no_match: true }
          end

          # Unmatched classifications
          unmatched_classifications =
            classification_names.each_with_index
                          .reject { |_, i| used_classifications[i] }
                          .map(&:first)

          [ result, unmatched_classifications ]
        end
      end
    end
  end
end
