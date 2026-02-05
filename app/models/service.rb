class Service < ApplicationRecord
  belongs_to :user

  scope :google_calendar, -> { where(provider: "google_oauth2") }

  def token_expired?
    expires_at.present? && expires_at < Time.current
  end

  def refresh_google_token!
    return unless provider == "google_oauth2" && refresh_token.present?

    response = HTTParty.post("https://oauth2.googleapis.com/token", body: {
      grant_type: "refresh_token",
      refresh_token: refresh_token,
      client_id: google_client_id,
      client_secret: google_client_secret
    })

    if response.success?
      data = response.parsed_response
      update!(
        access_token: data["access_token"],
        expires_at: Time.current + data["expires_in"].to_i.seconds
      )
    else
      Rails.logger.error "[Service#refresh_google_token!] Failed: #{response.body}"
      raise "Failed to refresh Google token: #{response.code}"
    end
  end

  private

  def google_client_id
    env_creds = Rails.application.credentials[Rails.env.to_sym] || {}
    env_creds.dig(:google, :app_id) || ENV["GOOGLE_CLIENT_ID"]
  end

  def google_client_secret
    env_creds = Rails.application.credentials[Rails.env.to_sym] || {}
    env_creds.dig(:google, :app_secret) || ENV["GOOGLE_CLIENT_SECRET"]
  end
end
