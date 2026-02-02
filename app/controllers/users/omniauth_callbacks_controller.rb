module Users
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    def facebook
      handle_oauth("Facebook")
    end

    def github
      handle_oauth("GitHub")
    end

    def twitter
      handle_oauth("Twitter")
    end

    def failure
      redirect_to root_path, alert: "Authentication failed. Please try again."
    end

    private

    def handle_oauth(provider)
      @user = User.from_omniauth(request.env["omniauth.auth"])

      if @user.persisted?
        convert_demo_calendar_if_present(@user)
        sign_in_and_redirect @user, event: :authentication
        set_flash_message(:notice, :success, kind: provider) if is_navigational_format?
      else
        session["devise.#{provider.downcase}_data"] = request.env["omniauth.auth"].except(:extra)
        redirect_to new_user_registration_url, alert: @user.errors.full_messages.join("\n")
      end
    end

    def convert_demo_calendar_if_present(user)
      return unless session[:demo_calendar].present? && session[:demo_calendar]["events"].present?

      result = DemoCalendarConversionService.call(
        user: user,
        session_data: session[:demo_calendar]
      )

      if result.success?
        flash[:notice] = "Welcome! Your demo calendar has been saved."
        session.delete(:demo_calendar)
      end
    end
  end
end
