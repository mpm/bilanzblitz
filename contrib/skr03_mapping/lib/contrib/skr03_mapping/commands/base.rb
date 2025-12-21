# frozen_string_literal: true

module Contrib
  module SKR03Mapping
    module Commands
      # Base class for all CLI commands.
      #
      # Provides shared functionality like banners, statistics printing, and
      # common options handling.
      class Base
        attr_reader :options

        # Initialize command with options hash.
        #
        # @param options [Hash] Command options
        def initialize(options = {})
          @options = options
        end

        # Execute the command (override in subclasses).
        #
        # @raise [NotImplementedError] Must be implemented by subclass
        def execute
          raise NotImplementedError, "#{self.class} must implement #execute"
        end

        protected

        # Returns the data directory path (default: current directory).
        #
        # @return [String] Data directory path
        def data_dir
          options[:data_dir] || "."
        end

        # Prints a formatted banner.
        #
        # @param title [String] Banner title
        # @param char [String] Character to use for banner (default: "=")
        # @param width [Integer] Banner width (default: 80)
        def print_banner(title, char: "=", width: 80)
          puts char * width
          puts title
          puts char * width
          puts
        end

        # Prints statistics hash in a formatted way.
        #
        # @param stats [Hash] Statistics hash
        # @param title [String, nil] Optional title for statistics section
        def print_stats(stats, title: nil)
          puts
          print_banner(title, char: "=") if title

          stats.each do |key, value|
            label = key.to_s.split('_').map(&:capitalize).join(' ')
            puts "  #{label}: #{value}"
          end
          puts
        end

        # Prints next steps instructions.
        #
        # @param steps [Array<String>] Array of step descriptions
        def print_next_steps(steps)
          puts "Next steps:"
          steps.each_with_index do |step, idx|
            puts "  #{idx + 1}. #{step}"
          end
          puts
        end

        # Prints success message.
        #
        # @param message [String] Success message
        def print_success(message)
          puts "✓ #{message}"
        end

        # Prints warning message.
        #
        # @param message [String] Warning message
        def print_warning(message)
          puts "⚠️  #{message}"
        end

        # Prints error message.
        #
        # @param message [String] Error message
        def print_error(message)
          puts "❌ #{message}"
        end
      end
    end
  end
end
