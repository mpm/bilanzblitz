# frozen_string_literal: true

module Contrib
  module SKR03Mapping
    module Commands
      # Command to perform a sanity check on the generated mappings.
      #
      # Verifies that all SKR03 classifications are properly accounted for,
      # either through direct mapping or through presentation rules.
      class SanityCheck < Base
        def execute
          ocr_file = options[:ocr_file] || File.join(data_dir, "skr03-ocr-results.json")
          mapping_file = options[:mapping] || File.join(data_dir, "skr03-section-mapping.yml")
          rules_file = options[:rules] || File.join(data_dir, "skr03-presentation-rules.yml")

          unless File.exist?(ocr_file)
            puts "Error: OCR results file not found at #{ocr_file}"
            exit 1
          end

          # Load classifications from OCR
          ocr_data = JSON.parse(File.read(ocr_file))
          all_classifications = ocr_data.map { |row| row[0]&.strip }.reject { |c| c.nil? || c.empty? }.uniq.sort

          # Load mapping
          mapping = File.exist?(mapping_file) ? YAML.load_file(mapping_file) : nil
          mapped_classifications = Set.new
          extract_mapped_classifications(mapping, mapped_classifications) if mapping

          # Load rules
          rules_data = File.exist?(rules_file) ? YAML.load_file(rules_file) : nil
          rule_classifications = Set.new
          if rules_data && rules_data["classifications"]
            rules_data["classifications"].each do |name, data|
              rule_classifications.add(name) if data["status"] != "unknown"
            end
          end

          # Perform check
          uncovered = all_classifications.reject do |c|
            mapped_classifications.include?(c) || rule_classifications.include?(c)
          end

          print_results(all_classifications, mapped_classifications, rule_classifications, uncovered)
        end

        private

        def extract_mapped_classifications(node, result)
          return unless node.is_a?(Hash)

          node.each do |key, value|
            if key == "_meta" || (value.is_a?(Hash) && (value.key?("skr03_classification") || value.key?("skr03_category")))
              val = value.is_a?(Hash) ? (value["skr03_classification"] || value["skr03_category"]) : node[key]
              Array(val).each { |c| result.add(c) } if val
            end

            extract_mapped_classifications(value, result) if value.is_a?(Hash)
          end
        end

        def print_results(all, mapped, rules, uncovered)
          puts "=" * 80
          puts "SKR03 Mapping Sanity Check"
          puts "=" * 80
          puts
          puts "Statistics:"
          puts "  Total classifications in OCR:     #{all.size}"
          puts "  Directly mapped (YAML):           #{mapped.size}"
          puts "  Handled by rules:                 #{rules.size}"
          puts "  Total covered:                    #{(mapped + rules).size}"
          puts "  Uncovered:                        #{uncovered.size}"
          puts

          if uncovered.any?
            puts "⚠️  WARNING: #{uncovered.size} classifications are not covered!"
            puts "They will not have a CID or presentation rule assigned."
            puts
            puts "Uncovered Classifications:"
            uncovered.each { |c| puts "- #{c}" }
          else
            puts "✅ Success: All classifications are covered!"
          end
          puts
        end
      end
    end
  end
end
