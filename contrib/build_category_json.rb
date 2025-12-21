#!/usr/bin/env ruby
# frozen_string_literal: true

#
# DEPRECATED: This script is now a thin wrapper around the new unified CLI.
#
# New Usage (Recommended):
#   ruby contrib/skr03_mapping/bin/skr03_mapper build-json
#
# This wrapper maintains backward compatibility with the original script.
#

# Add lib directory to load path
$LOAD_PATH.unshift(File.expand_path('skr03_mapping/lib', __dir__))

# Require the new implementation
require 'contrib'

# Change to script directory to maintain backward compatibility
Dir.chdir(File.dirname(__FILE__))

# Run the new implementation
puts "Note: Using new implementation. Run 'ruby contrib/skr03_mapping/bin/skr03_mapper build-json' directly."
puts

command = Contrib::SKR03Mapping::Commands::BuildJson.new
command.execute
