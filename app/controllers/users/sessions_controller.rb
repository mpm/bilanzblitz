class Users::SessionsController < Devise::SessionsController
  def new
    render inertia: "Auth/Login"
  end

  def create
    self.resource = warden.authenticate!(auth_options)
    sign_in(resource_name, resource)
    yield resource if block_given?
    redirect_to after_sign_in_path_for(resource)
  rescue
    render inertia: "Auth/Login", props: {
      errors: [ "Invalid email or password" ]
    }
  end

  def destroy
    signed_out = (Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name))
    yield if block_given?
    redirect_to after_sign_out_path_for(resource_name)
  end

  protected

  def after_sign_in_path_for(resource)
    if resource.companies.any?
      dashboard_path
    else
      onboarding_path
    end
  end

  def after_sign_out_path_for(resource_or_scope)
    root_path
  end

  private

  def auth_options
    { scope: resource_name, recall: "#{controller_path}#new" }
  end
end
