class Users::SessionsController < Devise::SessionsController
  def new
    render inertia: 'Auth/Login'
  end

  def create
    self.resource = warden.authenticate!(auth_options)
    sign_in(resource_name, resource)
    yield resource if block_given?
    redirect_to after_sign_in_path_for(resource)
  rescue
    render inertia: 'Auth/Login', props: {
      errors: ['Invalid email or password']
    }
  end

  def destroy
    signed_out = (Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name))
    yield if block_given?
    redirect_to after_sign_out_path_for(resource_name)
  end

  private

  def auth_options
    { scope: resource_name, recall: "#{controller_path}#new" }
  end
end
