class UserPreferencesController < ApplicationController
  before_action :authenticate_user!

  def update
    config = current_user.config || {}

    # Update the config based on params
    if params[:theme].present?
      config["ui"] ||= {}
      # Only accept "light" or "dark" as valid values
      config["ui"]["theme"] = %w[light dark].include?(params[:theme]) ? params[:theme] : "light"
    end

    if current_user.update(config: config)
      render json: { success: true, config: current_user.config }
    else
      render json: { success: false, errors: current_user.errors.full_messages }, status: :unprocessable_entity
    end
  end
end
