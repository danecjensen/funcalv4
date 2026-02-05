class CalendarConnectionsController < ApplicationController
  before_action :authenticate_user!

  def index
    @google_configured = google_oauth_configured?
    @google_connected = current_user.services.google_calendar.exists?
    @google_calendars = current_user.calendars.where(import_source: "google")
    @apple_calendars = current_user.calendars.where(import_source: "apple")
    @ical_calendars = current_user.calendars.where(import_source: "ical")
  end

  def create
    source = params[:source]
    url = params[:import_url]

    if url.blank?
      redirect_to calendar_connections_path, alert: "Please provide a calendar URL."
      return
    end

    import_source = source == "apple" ? "apple" : "ical"
    name = params[:name].presence || "#{import_source.titleize} Calendar"

    calendar = current_user.calendars.create!(
      name: name,
      import_url: url,
      import_source: import_source,
      import_enabled: true
    )

    IcalImportJob.perform_later(calendar.id)
    redirect_to profile_path, notice: "#{name} connected. Events are being imported."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to calendar_connections_path, alert: e.record.errors.full_messages.join(", ")
  end

  private

  def google_oauth_configured?
    env_creds = Rails.application.credentials[Rails.env.to_sym] || {}
    client_id = env_creds.dig(:google, :app_id) || ENV["GOOGLE_CLIENT_ID"]
    client_id.present?
  end
end
