module Api
  module V1
    class BaseController < ActionController::API
      include ActionController::Cookies
      include Pundit::Authorization

      before_action :authenticate_api_user!

      private

      def authenticate_api_user!
        # For development: Allow requests from localhost without authentication
        return if Rails.env.development? && request_from_localhost?

        # For production: Require authentication via session or token
        unless current_user
          render json: { error: "Unauthorized" }, status: :unauthorized
        end
      end

      def current_user
        # Try Bearer token first, then Devise session
        @current_user ||= user_from_token || warden&.user(:user)
      end

      def user_from_token
        header = request.headers["Authorization"]
        return unless header&.start_with?("Bearer ")

        token = header.split(" ", 2).last
        User.find_by(api_token: token)
      end

      def warden
        request.env["warden"]
      end

      def request_from_localhost?
        ["127.0.0.1", "::1", "localhost"].include?(request.remote_ip) ||
          request.origin&.match?(/\Ahttps?:\/\/(localhost|127\.0\.0\.1)/)
      end

      def default_user_for_development
        User.first
      end

      def api_user
        current_user || (Rails.env.development? && default_user_for_development)
      end

      # Pundit uses this to resolve the user for policy_scope / authorize
      def pundit_user
        api_user
      end
    end
  end
end
