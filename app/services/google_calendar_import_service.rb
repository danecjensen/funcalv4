# Service for importing events from Google Calendar API
#
# Usage:
#   result = GoogleCalendarImportService.call(calendar)
#   if result.success?
#     puts "Imported #{result.event_count} events"
#   else
#     puts "Error: #{result.error}"
#   end
#
class GoogleCalendarImportService
  Result = Struct.new(:success?, :event_count, :error, keyword_init: true) do
    def success? = self[:success?]
  end

  def self.call(calendar)
    new(calendar).call
  end

  def initialize(calendar)
    @calendar = calendar
  end

  def call
    return Result.new(success?: false, error: "Not a Google Calendar") unless @calendar.google?
    return Result.new(success?: false, error: "No import_source_id configured") if @calendar.import_source_id.blank?

    service_record = @calendar.user.services.google_calendar.first
    return Result.new(success?: false, error: "No Google account connected") unless service_record

    # Refresh token if expired
    service_record.refresh_google_token! if service_record.token_expired?

    calendar_service = build_google_service(service_record.access_token)

    event_count = 0
    page_token = nil

    loop do
      response = calendar_service.list_events(
        @calendar.import_source_id,
        time_min: 30.days.ago.iso8601,
        time_max: 1.year.from_now.iso8601,
        single_events: true,
        order_by: "startTime",
        max_results: 250,
        page_token: page_token
      )

      response.items&.each do |google_event|
        next if google_event.start.nil?

        start_time = parse_google_datetime(google_event.start)
        next unless start_time

        event = find_or_initialize_event(google_event.id)
        event.assign_attributes(
          title: (google_event.summary || "Untitled").truncate(255),
          starts_at: start_time,
          ends_at: parse_google_datetime(google_event.end),
          location: google_event.location.to_s.truncate(500),
          description: google_event.description.to_s.truncate(2000),
          all_day: google_event.start.date.present?,
          source_name: "google",
          source_url: google_event.html_link
        )

        if event.save
          event_count += 1
        else
          Rails.logger.warn "[GoogleCalendarImportService] Failed to save event: #{event.errors.full_messages.join(', ')}"
        end
      end

      page_token = response.next_page_token
      break if page_token.nil?
    end

    @calendar.update!(
      last_imported_at: Time.current,
      import_error: nil
    )

    Result.new(success?: true, event_count: event_count)
  rescue Google::Apis::AuthorizationError => e
    @calendar.update!(import_error: "Authorization expired. Please reconnect Google Calendar.")
    Result.new(success?: false, error: "Authorization expired: #{e.message}")
  rescue => e
    @calendar.update!(import_error: e.message)
    Rails.logger.error "[GoogleCalendarImportService] Error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    Result.new(success?: false, error: e.message)
  end

  private

  def build_google_service(access_token)
    service = Google::Apis::CalendarV3::CalendarService.new
    service.authorization = Signet::OAuth2::Client.new(access_token: access_token)
    service
  end

  def parse_google_datetime(dt)
    return nil if dt.nil?

    if dt.date.present?
      Date.parse(dt.date).beginning_of_day
    elsif dt.date_time.present?
      dt.date_time.to_time
    end
  end

  def find_or_initialize_event(google_event_id)
    existing = @calendar.events.find_by(source_id: google_event_id)
    return existing if existing

    @calendar.events.build(source_id: google_event_id)
  end
end
