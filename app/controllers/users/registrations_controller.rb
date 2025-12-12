class Users::RegistrationsController < Devise::RegistrationsController
  def new
    render inertia: "Auth/Register"
  end

  def create
    build_resource(sign_up_params)

    resource.save
    yield resource if block_given?
    if resource.persisted?
      if resource.active_for_authentication?
        sign_up(resource_name, resource)
        redirect_to after_sign_up_path_for(resource)
      else
        expire_data_after_sign_in!
        redirect_to after_inactive_sign_up_path_for(resource)
      end
    else
      clean_up_passwords resource
      set_minimum_password_length
      render inertia: "Auth/Register", props: {
        errors: resource.errors.full_messages
      }
    end
  end

  protected

  def after_sign_up_path_for(resource)
    onboarding_path
  end

  private

  def sign_up_params
    params.permit(:email, :password, :password_confirmation)
  end
end
