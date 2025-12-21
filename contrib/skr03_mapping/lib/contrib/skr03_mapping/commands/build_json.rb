# frozen_string_literal: true

module Contrib
  module SKR03Mapping
    module Commands
      # Command to build final JSON and CSV files.
      #
      # Wraps the ClassificationJsonBuilder and provides CLI interface.
      class BuildJson < Base
        # Execute the build-json command.
        def execute
          print_banner("Building Classification JSON Files from Mapping")

          # Get file paths from options or use defaults
          mapping_file = options[:mapping] || "skr03-section-mapping.yml"
          ocr_file = options[:ocr_file] || "skr03-ocr-results.json"
          rules_file = options[:rules] || "skr03-presentation-rules.yml"
          output_dir = options[:output_dir] || data_dir

          # Resolve paths relative to data_dir if not absolute
          mapping_path = File.absolute_path?(mapping_file) ? mapping_file : File.join(data_dir, mapping_file)
          ocr_path = File.absolute_path?(ocr_file) ? ocr_file : File.join(data_dir, ocr_file)
          rules_path = File.absolute_path?(rules_file) ? rules_file : File.join(data_dir, rules_file)

          # HGB structure files
          bilanz_aktiva_path = File.join(data_dir, "hgb-bilanz-aktiva.json")
          bilanz_passiva_path = File.join(data_dir, "hgb-bilanz-passiva.json")
          guv_path = File.join(data_dir, "hgb-guv.json")

          # Create builder
          builder = Generators::ClassificationJsonBuilder.new(
            mapping_path: mapping_path,
            ocr_path: ocr_path,
            presentation_rules_path: rules_path,
            bilanz_aktiva_path: bilanz_aktiva_path,
            bilanz_passiva_path: bilanz_passiva_path,
            guv_path: guv_path
          )

          # Build all data structures
          data = builder.build

          # Write output files
          bilanz_output = File.join(output_dir, "bilanz-sections-mapping.json")
          guv_output = File.join(output_dir, "guv-sections-mapping.json")
          csv_output = File.join(output_dir, "skr03-accounts.csv")

          builder.write_bilanz_json(bilanz_output, data[:bilanz])
          print_success("Generated bilanz-sections-mapping.json")

          builder.write_guv_json(guv_output, data[:guv])
          print_success("Generated guv-sections-mapping.json")

          builder.write_csv(csv_output, data[:csv_data])
          print_success("Generated skr03-accounts.csv")

          puts
          puts "Done! Final JSON files have been generated."
          puts
        end
      end
    end
  end
end
