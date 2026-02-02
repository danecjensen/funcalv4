module Users
  class RegistrationsController < Devise::RegistrationsController
    protected

    # After successful signup, convert any demo calendar to a real one
    def after_sign_up_path_for(resource)
      convert_demo_calendar_if_pending(resource)
      super
    end

    def after_inactive_sign_up_path_for(resource)
      convert_demo_calendar_if_pending(resource)
      super
    end

    private

    def convert_demo_calendar_if_pending(user)
      return unless session[:demo_persist_pending] || session[:demo_calendar].present?

      if session[:demo_calendar].present? && session[:demo_calendar]["events"].present?
        result = DemoCalendarConversionService.call(
          user: user,
          session_data: session[:demo_calendar]
        )

        if result.success?
          flash[:notice] = "Welcome! Your demo calendar has been saved."
          session.delete(:demo_calendar)
          session.delete(:demo_persist_pending)
          return calendar_path(result.calendar)
        end
      end

      session.delete(:demo_persist_pending)
      nil
    end
  end
end
