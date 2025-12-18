class ApplicationController < ActionController::Base
  include KeyTransformer

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  inertia_share do
    fiscal_years = if current_user&.companies&.any?
      current_user.companies.first.fiscal_years.order(year: :desc).map { |fy|
        {
          id: fy.id,
          year: fy.year,
          closed: fy.closed
        }
      }
    else
      []
    end

    {
      userConfig: current_user&.config || {},
      fiscalYears: fiscal_years
    }
  end

  protected

  # Get the user's preferred fiscal year for a company
  # Returns the year (integer) if found, nil otherwise
  def preferred_fiscal_year_for_company(company_id)
    return nil unless current_user&.config

    fiscal_years = current_user.config.dig("fiscal_years")
    return nil unless fiscal_years

    fiscal_years[company_id.to_s]&.to_i
  end
end
