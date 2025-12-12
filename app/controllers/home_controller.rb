class HomeController < ApplicationController
  def index
    # Redirect authenticated users to appropriate page
    if user_signed_in?
      if current_user.companies.any?
        redirect_to dashboard_path
      else
        redirect_to onboarding_path
      end
      return
    end

    render inertia: "Home/Index"
  end
end
