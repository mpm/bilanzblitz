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

    # Update fiscal year preference for a company
    if params[:fiscal_year].present? && params[:company_id].present?
      config["fiscal_years"] ||= {}
      year = params[:fiscal_year].to_i
      company_id = params[:company_id].to_s

      # Validate that the year is reasonable (between 1900 and 2100)
      if year.between?(1900, 2100)
        config["fiscal_years"][company_id] = year
      end
    end

    if current_user.update(config: config)
      render json: { success: true, config: current_user.config }
    else
      render json: { success: false, errors: current_user.errors.full_messages }, status: :unprocessable_entity
    end
  end
end
