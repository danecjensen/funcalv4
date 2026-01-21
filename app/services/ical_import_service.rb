# Service for importing events from iCal feeds (Google Calendar, Apple Calendar, etc.)
#
# Usage:
#   result = IcalImportService.call(calendar)
#   if result.success?
#     puts "Imported #{result.event_count} events"
#   else
#     puts "Error: #{result.error}"
#   end
#
class IcalImportService
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
    return Result.new(success?: false, error: "No import URL configured") if @calendar.import_url.blank?

    url = normalize_url(@calendar.import_url)
    response = fetch_ical(url)

    return Result.new(success?: false, error: "Failed to fetch iCal feed") unless response

    ical = Icalendar::Calendar.parse(response).first
    return Result.new(success?: false, error: "Invalid iCal format") unless ical

    event_count = 0
    ical.events.each do |ical_event|
      next if ical_event.dtstart.nil?

      # Parse start time
      start_time = parse_ical_datetime(ical_event.dtstart)
      next unless start_time

      # Skip past events older than 30 days
      next if start_time < 30.days.ago

      event = find_or_initialize_event(ical_event)
      event.assign_attributes(
        title: ical_event.summary.to_s.truncate(255),
        starts_at: start_time,
        ends_at: parse_ical_datetime(ical_event.dtend),
        location: ical_event.location.to_s.truncate(500),
        description: ical_event.description.to_s.truncate(2000),
        all_day: ical_event.dtstart.is_a?(Icalendar::Values::Date),
        source_name: @calendar.import_source || "ical",
        source_url: @calendar.import_url
      )

      if event.save
        event_count += 1
      else
        Rails.logger.warn "[IcalImportService] Failed to save event: #{event.errors.full_messages.join(', ')}"
      end
    end

    @calendar.update!(
      last_imported_at: Time.current,
      import_error: nil
    )

    Result.new(success?: true, event_count: event_count)
  rescue => e
    @calendar.update!(import_error: e.message)
    Rails.logger.error "[IcalImportService] Error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    Result.new(success?: false, error: e.message)
  end

  private

  def normalize_url(url)
    # Convert webcal:// to https://
    url.to_s.gsub(/^webcal:\/\//, "https://")
  end

  def fetch_ical(url)
    response = HTTParty.get(url, {
      headers: { "User-Agent" => "Community Calendar/1.0" },
      timeout: 30,
      follow_redirects: true
    })

    response.success? ? response.body : nil
  rescue => e
    Rails.logger.error "[IcalImportService] Fetch error: #{e.message}"
    nil
  end

  def parse_ical_datetime(value)
    return nil if value.nil?

    case value
    when Icalendar::Values::Date
      value.to_date.beginning_of_day
    when Icalendar::Values::DateTime
      value.to_time
    when Time, DateTime
      value.to_time
    when Date
      value.beginning_of_day
    else
      Time.zone.parse(value.to_s) rescue nil
    end
  end

  def find_or_initialize_event(ical_event)
    uid = ical_event.uid.to_s

    # Try to find by source_id (UID)
    existing = @calendar.events.find_by(source_id: uid) if uid.present?
    return existing if existing

    # Create new
    @calendar.events.build(source_id: uid)
  end
end
