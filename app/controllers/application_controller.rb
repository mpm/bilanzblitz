class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  inertia_share do
    {
      userConfig: current_user&.config || {}
    }
  end

  protected

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
end
