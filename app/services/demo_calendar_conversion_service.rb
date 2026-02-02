# Converts a session-based demo calendar to a persisted calendar
# associated with a signed-in user.
#
# Usage:
#   result = DemoCalendarConversionService.call(user: current_user, session_data: session[:demo_calendar])
#   if result.success?
#     result.calendar  # The created calendar
#     result.events    # Array of created events
#   else
#     result.errors    # Array of error messages
#   end
#
class DemoCalendarConversionService
  Result = Struct.new(:success?, :calendar, :events, :errors, keyword_init: true) do
    def success? = self[:success?]
  end

  def self.call(**args)
    new(**args).call
  end

  def initialize(user:, session_data:)
    @user = user
    @session_data = session_data || {}
  end

  def call
    return empty_result if @session_data.blank? || session_events.blank?

    ActiveRecord::Base.transaction do
      calendar = create_calendar
      events = create_events(calendar)

      Result.new(
        success?: true,
        calendar: calendar,
        events: events,
        errors: []
      )
    end
  rescue ActiveRecord::RecordInvalid => e
    Result.new(
      success?: false,
      calendar: nil,
      events: [],
      errors: e.record.errors.full_messages
    )
  rescue StandardError => e
    Result.new(
      success?: false,
      calendar: nil,
      events: [],
      errors: [e.message]
    )
  end

  private

  def empty_result
    Result.new(
      success?: false,
      calendar: nil,
      events: [],
      errors: ["No demo events to convert"]
    )
  end

  def session_events
    @session_data["events"] || []
  end

  def create_calendar
    @user.calendars.create!(
      name: @session_data["name"] || "My Calendar",
      description: "Converted from demo calendar",
      color: @session_data["color"] || "#9B59B6"
    )
  end

  def create_events(calendar)
    session_events.map do |event_data|
      calendar.events.create!(
        title: event_data["title"],
        starts_at: parse_time(event_data["starts_at"]),
        ends_at: parse_time(event_data["ends_at"]),
        location: event_data["location"],
        description: event_data["description"],
        event_type: event_data["event_type"] || "social"
      )
    end
  end

  def parse_time(value)
    return nil if value.blank?
    Time.zone.parse(value)
  rescue ArgumentError, TypeError
    nil
  end
end
