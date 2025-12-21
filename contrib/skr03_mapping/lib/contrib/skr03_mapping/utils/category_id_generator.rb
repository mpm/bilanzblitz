# frozen_string_literal: true

module Contrib
  module SKR03Mapping
    module Utils
      # Generates hierarchical category IDs from German category names.
      #
      # Converts German text to slugified, filesystem-safe IDs with proper handling
      # of German characters (ä, ö, ü, ß) and ensures uniqueness.
      module CategoryIdGenerator
        # Generates hierarchical category ID from German category name
        #
        # @param name [String] The German category name
        # @param existing_ids [Array<String>] List of already used IDs to ensure uniqueness
        # @return [String] The generated ID
        #
        # @example
        #   CategoryIdGenerator.generate_id("Geschäfts- oder Firmenwert")
        #   # => "geschaefts_oder_firmenwert"
        #
        #   CategoryIdGenerator.generate_id("Test", ["test"])
        #   # => "test_2"
        def self.generate_id(name, existing_ids = [])
          # Convert to lowercase
          id = name.downcase

          # German character replacements
          id = id.gsub('ä', 'ae').gsub('ö', 'oe').gsub('ü', 'ue').gsub('ß', 'ss')

          # Remove punctuation and special chars
          id = id.gsub(/[,;:.()\[\]\/"']/, '')

          # Replace spaces and dashes with underscores
          id = id.gsub(/[\s\-]+/, '_')

          # Remove any remaining non-alphanumeric (except underscore)
          id = id.gsub(/[^a-z0-9_]/, '')

          # Collapse multiple underscores
          id = id.gsub(/_+/, '_')

          # Remove leading/trailing underscores
          id = id.gsub(/^_+|_+$/, '')

          # Truncate if too long (keep first 60 chars)
          id = id[0..59] if id.length > 60

          # Ensure uniqueness
          if existing_ids.include?(id)
            counter = 2
            while existing_ids.include?("#{id}_#{counter}")
              counter += 1
            end
            id = "#{id}_#{counter}"
          end

          id
        end
      end
    end
  end
end
