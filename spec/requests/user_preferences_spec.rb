require 'rails_helper'

RSpec.describe "UserPreferences", type: :request do
  describe "GET /update" do
    xit "returns http success" do
      get "/user_preferences/update"
      expect(response).to have_http_status(:success)
    end
  end
end
