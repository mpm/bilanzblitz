class ApplicationController < ActionController::Base
  include KeyTransformer

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  inertia_share do
    {
      userConfig: current_user&.config || {}
    }
  end
end
