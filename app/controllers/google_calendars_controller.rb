class GoogleCalendarsController < ApplicationController
  before_action :authenticate_user!

  def index
    authorize :google_calendar

    service_record = current_user.services.google_calendar.first
    unless service_record
      redirect_to calendar_connections_path, alert: "Please connect your Google account first."
      return
    end

    service_record.refresh_google_token! if service_record.token_expired?

    calendar_service = Google::Apis::CalendarV3::CalendarService.new
    calendar_service.authorization = Signet::OAuth2::Client.new(access_token: service_record.access_token)

    @google_calendars = calendar_service.list_calendar_lists.items
    @existing_source_ids = current_user.calendars.where(import_source: "google").pluck(:import_source_id)
  rescue Google::Apis::AuthorizationError
    redirect_to calendar_connections_path, alert: "Google authorization expired. Please reconnect."
  rescue => e
    Rails.logger.error "[GoogleCalendarsController#index] Error: #{e.message}"
    redirect_to calendar_connections_path, alert: "Failed to load Google Calendars. Please try again."
  end

  def create
    authorize :google_calendar

    calendar_ids = params[:calendar_ids] || []

    if calendar_ids.empty?
      redirect_to google_calendars_path, alert: "Please select at least one calendar."
      return
    end

    service_record = current_user.services.google_calendar.first
    unless service_record
      redirect_to calendar_connections_path, alert: "Please connect your Google account first."
      return
    end

    service_record.refresh_google_token! if service_record.token_expired?

    calendar_service = Google::Apis::CalendarV3::CalendarService.new
    calendar_service.authorization = Signet::OAuth2::Client.new(access_token: service_record.access_token)

    created_count = 0
    calendar_ids.each do |google_cal_id|
      next if current_user.calendars.exists?(import_source: "google", import_source_id: google_cal_id)

      begin
        google_cal = calendar_service.get_calendar_list_entry(google_cal_id)

        calendar = current_user.calendars.create!(
          name: google_cal.summary.truncate(255),
          color: google_cal.background_color || "#3788d8",
          import_source: "google",
          import_source_id: google_cal_id,
          import_enabled: true
        )

        GoogleCalendarImportJob.perform_later(calendar.id)
        created_count += 1
      rescue => e
        Rails.logger.error "[GoogleCalendarsController#create] Failed to create calendar #{google_cal_id}: #{e.message}"
      end
    end

    redirect_to profile_path, notice: "#{created_count} Google #{'calendar'.pluralize(created_count)} connected. Events are being imported."
  end

  def destroy
    calendar = current_user.calendars.find(params[:id])
    authorize calendar, policy_class: GoogleCalendarPolicy

    calendar.update!(import_enabled: false, import_source: nil, import_source_id: nil)
    redirect_to profile_path, notice: "Google Calendar disconnected."
  end

  def refresh
    calendar = current_user.calendars.find(params[:id])
    authorize calendar, policy_class: GoogleCalendarPolicy

    GoogleCalendarImportJob.perform_later(calendar.id)
    redirect_to profile_path, notice: "Sync started for #{calendar.name}."
  end
end
