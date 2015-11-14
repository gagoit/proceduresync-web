class PasswordsController < Devise::PasswordsController
  #layout "not_signed_in"

  # POST /resource/password
  def create
    self.resource = User.find_or_initialize_with_errors([:email], resource_params, :not_found)
    @success = false

    if !resource.new_record?
      resource.reset_password!
      @success = true

      respond_to do |format|
        format.html {
          set_flash_message :notice, :send_instructions
          respond_with({}, location: after_sending_reset_password_instructions_path_for(resource_name))
        }

        format.js {}
      end
    else
      respond_to do |format|
        format.html {
          respond_with(resource)
        }

        format.js {}
      end
    end
  end
end