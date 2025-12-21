# frozen_string_literal: true

# Top-level require file for Contrib::SKR03Mapping
#
# Requires all modules and classes in the proper order to ensure
# dependencies are loaded before dependent classes.

# Require rules (no dependencies)
require_relative 'contrib/skr03_mapping/rules/presentation_rule_definitions'

# Require utilities (no dependencies)
require_relative 'contrib/skr03_mapping/utils/fuzzy_matcher'
require_relative 'contrib/skr03_mapping/utils/category_id_generator'
require_relative 'contrib/skr03_mapping/utils/parser_tools'

# Require detectors (no dependencies)
require_relative 'contrib/skr03_mapping/detectors/presentation_rule_detector'

# Require generators (depend on utils and detectors)
require_relative 'contrib/skr03_mapping/generators/classification_mapping_generator'
require_relative 'contrib/skr03_mapping/generators/presentation_rules_generator'
require_relative 'contrib/skr03_mapping/generators/classification_json_builder'

# Require commands (depend on generators)
require_relative 'contrib/skr03_mapping/commands/base'
require_relative 'contrib/skr03_mapping/commands/generate_mapping'
require_relative 'contrib/skr03_mapping/commands/generate_rules'
require_relative 'contrib/skr03_mapping/commands/build_json'
require_relative 'contrib/skr03_mapping/commands/sanity_check'

# Require CLI (depends on commands)
require_relative 'contrib/skr03_mapping/cli'
