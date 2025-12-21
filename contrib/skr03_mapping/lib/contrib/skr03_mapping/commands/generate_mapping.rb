# frozen_string_literal: true

module Contrib
  module SKR03Mapping
    module Commands
      # Command to generate classification mapping YAML file.
      #
      # Wraps the ClassificationMappingGenerator and provides CLI interface.
      class GenerateMapping < Base
        # Execute the generate-mapping command.
        def execute
          print_banner("Classification Mapping Generator - SKR03 to HGB")

          output_file = options[:output] || "skr03-section-mapping.yml"

          # Resolve output path relative to data_dir if not absolute
          output_path = File.absolute_path?(output_file) ? output_file : File.join(data_dir, output_file)

          # Create generator
          generator = Generators::ClassificationMappingGenerator.new(data_dir)

          # Generate mapping
          mapping = generator.generate

          # Write YAML file
          generator.write_yaml(output_path, mapping)

          # Print statistics
          generator.print_stats

          # Print completion message
          print_success("Generated #{output_path}")

          # Print next steps
          unmatched = generator.unmatched_skr03_classifications
          print_next_steps([
            "Review #{output_path} and fix any incorrect matches",
            "Check unmatched SKR03 classifications at the end of the file",
            "Manually assign unmatched SKR03 classifications to appropriate HGB categories",
            "Run: bin/skr03_mapper generate-rules"
          ])
        end
      end
    end
  end
end
