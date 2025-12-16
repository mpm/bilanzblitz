# Shared module for transforming hash keys between camelCase and snake_case
# Used for Rails <-> JavaScript interoperability
module KeyTransformer
  extend ActiveSupport::Concern

  # Recursively converts hash keys from snake_case to camelCase
  # Useful for serializing data for JavaScript/TypeScript frontends
  # Handles nested hashes and arrays
  def camelize_keys(value)
    case value
    when Hash
      value.transform_keys { |key| key.to_s.camelize(:lower) }
           .transform_values { |v| camelize_keys(v) }
    when Array
      value.map { |v| camelize_keys(v) }
    else
      value
    end
  end

  # Recursively converts hash keys from camelCase to snake_case
  # Useful for parsing data from JavaScript/TypeScript frontends
  # Handles nested hashes and arrays
  def underscore_keys(value)
    case value
    when Hash
      value.transform_keys { |key| key.to_s.underscore.to_sym }
           .transform_values { |v| underscore_keys(v) }
    when Array
      value.map { |v| underscore_keys(v) }
    when ActionController::Parameters
      underscore_keys(value.to_unsafe_h)
    else
      value
    end
  end
end
