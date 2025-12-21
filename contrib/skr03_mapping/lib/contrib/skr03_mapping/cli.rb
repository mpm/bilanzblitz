# frozen_string_literal: true

module Contrib
  module SKR03Mapping
    # CLI router for SKR03 mapping commands.
    #
    # Routes subcommands to appropriate command classes and handles argument parsing.
    class CLI
      COMMANDS = {
        'generate-mapping' => Commands::GenerateMapping,
        'map-categories' => Commands::GenerateMapping, # Alias
        'generate-rules' => Commands::GenerateRules,
        'detect-rules' => Commands::GenerateRules, # Alias
        'build-json' => Commands::BuildJson,
        'build' => Commands::BuildJson # Alias
      }.freeze

      # Start the CLI with given arguments.
      #
      # @param args [Array<String>] Command line arguments
      def self.start(args)
        command_name = args.shift

        # Handle help command
        if command_name.nil? || command_name == 'help'
          print_help(args.first)
          return
        end

        # Find command class
        command_class = COMMANDS[command_name]

        unless command_class
          puts "Error: Unknown command '#{command_name}'"
          puts
          print_help
          exit 1
        end

        # Parse options
        options = parse_options(args)

        # Create and execute command
        command = command_class.new(options)
        command.execute
      rescue StandardError => e
        puts "Error: #{e.message}"
        puts e.backtrace if options[:debug]
        exit 1
      end

      # Parse command line options.
      #
      # @param args [Array<String>] Remaining arguments after command name
      # @return [Hash] Parsed options
      def self.parse_options(args)
        options = {}

        while args.any?
          arg = args.shift

          case arg
          when '--data-dir'
            options[:data_dir] = args.shift
          when '--output', '-o'
            options[:output] = args.shift
          when '--ocr-file'
            options[:ocr_file] = args.shift
          when '--mapping'
            options[:mapping] = args.shift
          when '--rules'
            options[:rules] = args.shift
          when '--output-dir'
            options[:output_dir] = args.shift
          when '--debug'
            options[:debug] = true
          when '--help', '-h'
            print_help
            exit 0
          else
            puts "Warning: Unknown option '#{arg}'"
          end
        end

        options
      end

      # Print help message.
      #
      # @param command_name [String, nil] Specific command to show help for
      def self.print_help(command_name = nil)
        if command_name && COMMANDS[command_name]
          print_command_help(command_name)
        else
          print_general_help
        end
      end

      # Print general help message.
      def self.print_general_help
        puts <<~HELP
          SKR03 Mapper - Unified CLI for SKR03 to HGB Mapping

          Usage:
            skr03_mapper COMMAND [OPTIONS]

          Commands:
            generate-mapping    Generate classification mapping YAML (alias: map-categories)
            generate-rules      Generate presentation rules YAML (alias: detect-rules)
            build-json          Build final JSON and CSV files (alias: build)
            help [COMMAND]      Show help for a specific command

          Options:
            --help, -h          Show this help message

          Examples:
            # Generate category mapping
            ruby contrib/skr03_mapping/bin/skr03_mapper generate-mapping

            # Generate presentation rules
            ruby contrib/skr03_mapping/bin/skr03_mapper generate-rules

            # Build final JSON files
            ruby contrib/skr03_mapping/bin/skr03_mapper build-json

          For more information on a specific command, run:
            skr03_mapper help COMMAND
        HELP
      end

      # Print help for a specific command.
      #
      # @param command_name [String] Command name
      def self.print_command_help(command_name)
        case command_name
        when 'generate-mapping', 'map-categories'
          puts <<~HELP
            Generate Classification Mapping YAML

            Usage:
              skr03_mapper generate-mapping [OPTIONS]

            Options:
              --data-dir DIR      Input data directory (default: current directory)
              --output FILE       Output YAML file (default: skr03-section-mapping.yml)
              --help, -h          Show this help message

            Description:
              Generates an intermediate YAML mapping file that maps official HGB
              balance sheet and GuV categories to SKR03 account classifications.

              The generated mapping can be manually edited before running build-json.

            Input Files (in data-dir):
              - hgb-bilanz-aktiva.json
              - hgb-bilanz-passiva.json
              - hgb-guv.json
              - skr03-ocr-results.json

            Output:
              - skr03-section-mapping.yml (human-editable)

            Example:
              ruby contrib/skr03_mapping/bin/skr03_mapper generate-mapping --output my-mapping.yml
          HELP

        when 'generate-rules', 'detect-rules'
          puts <<~HELP
            Generate Presentation Rules YAML

            Usage:
              skr03_mapper generate-rules [OPTIONS]

            Options:
              --ocr-file FILE     OCR results file (default: skr03-ocr-results.json)
              --output FILE       Output YAML file (default: skr03-presentation-rules.yml)
              --data-dir DIR      Input data directory (default: current directory)
              --help, -h          Show this help message

            Description:
              Analyzes SKR03 classifications to detect saldo-dependent account
              patterns and generates a YAML file for manual review.

            Input Files:
              - skr03-ocr-results.json

            Output:
              - skr03-presentation-rules.yml (human-editable)

            Example:
              ruby contrib/skr03_mapping/bin/skr03_mapper generate-rules --output my-rules.yml
          HELP

        when 'build-json', 'build'
          puts <<~HELP
            Build Final JSON and CSV Files

            Usage:
              skr03_mapper build-json [OPTIONS]

            Options:
              --mapping FILE      Section mapping YAML (default: skr03-section-mapping.yml)
              --ocr-file FILE     OCR results JSON (default: skr03-ocr-results.json)
              --rules FILE        Presentation rules YAML (default: skr03-presentation-rules.yml)
              --output-dir DIR    Output directory (default: current directory)
              --data-dir DIR      Input data directory (default: current directory)
              --help, -h          Show this help message

            Description:
              Builds final JSON mapping files and CSV account list from validated
              YAML mappings.

            Input Files (in data-dir):
              - skr03-section-mapping.yml (validated)
              - skr03-presentation-rules.yml (validated)
              - skr03-ocr-results.json
              - hgb-bilanz-aktiva.json
              - hgb-bilanz-passiva.json
              - hgb-guv.json

            Output Files (in output-dir):
              - bilanz-sections-mapping.json
              - guv-sections-mapping.json
              - skr03-accounts.csv

            Example:
              ruby contrib/skr03_mapping/bin/skr03_mapper build-json --output-dir output/
          HELP
        end
      end
    end
  end
end
