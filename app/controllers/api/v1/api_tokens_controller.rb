module Api
  module V1
    class ApiTokensController < BaseController
      # Token management requires session auth (can't use a token to create a token)
      # Override to skip Bearer token — only session or localhost bypass
      def create
        user = api_user
        unless user
          render json: { error: "Must be signed in to generate a token" }, status: :unauthorized
          return
        end

        user.regenerate_api_token

        render json: { api_token: user.api_token }, status: :created
      end

      def destroy
        user = api_user
        unless user
          render json: { error: "Unauthorized" }, status: :unauthorized
          return
        end

        user.update!(api_token: nil)

        render json: { message: "API token revoked" }
      end
    end
  end
end
