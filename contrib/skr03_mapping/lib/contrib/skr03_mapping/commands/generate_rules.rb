# frozen_string_literal: true

module Contrib
  module SKR03Mapping
    module Commands
      # Command to generate presentation rules YAML file.
      #
      # Wraps the PresentationRulesGenerator and provides CLI interface.
      class GenerateRules < Base
        # Execute the generate-rules command.
        def execute
          print_banner("Presentation Rules Generator - SKR03 Saldo Detection")

          ocr_file = options[:ocr_file] || "skr03-ocr-results.json"
          output_file = options[:output] || "skr03-presentation-rules.yml"

          # Resolve paths relative to data_dir if not absolute
          ocr_path = File.absolute_path?(ocr_file) ? ocr_file : File.join(data_dir, ocr_file)

          # Create generator
          generator = Generators::PresentationRulesGenerator.new(ocr_path)

          # Generate rules
          classifications = generator.generate

          # Write YAML file
          output_path = File.absolute_path?(output_file) ? output_file : File.join(data_dir, output_file)
          generator.write_yaml(output_path, classifications)

          # Print statistics
          generator.print_stats

          # Print completion message
          print_success("Generated #{output_file}")

          # Print next steps
          print_next_steps([
            "Review #{output_file}",
            "Verify/fix detected rules, especially 'needs_review' entries",
            "Assign rules to 'unknown' classifications",
            "Run: ruby contrib/skr03_mapping/bin/skr03_mapper build-json"
          ])
        end
      end
    end
  end
end
