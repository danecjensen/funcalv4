module Demo
  class CalendarsController < ApplicationController
    # No authentication required for demo pages

    MAX_DEMO_EVENTS = 50

    def show
      initialize_demo_calendar
      @demo_calendars = demo_calendars_for_display
    end

    def events
      initialize_demo_calendar

      start_date = params[:start].present? ? Time.zone.parse(params[:start]) : Time.current.beginning_of_month
      end_date = params[:end].present? ? Time.zone.parse(params[:end]) : Time.current.end_of_month

      # Combine demo calendar events with user's session events
      all_events = demo_events_in_range(start_date, end_date) + session_events_in_range(start_date, end_date)

      render json: all_events.map { |event| event_to_json(event) }
    end

    def persist
      unless user_signed_in?
        # Store intent to persist in session for after signup
        session[:demo_persist_pending] = true
        redirect_to new_user_registration_path, notice: "Sign up to save your calendar!"
        return
      end

      result = DemoCalendarConversionService.call(
        user: current_user,
        session_data: session[:demo_calendar]
      )

      if result.success?
        session.delete(:demo_calendar)
        redirect_to calendar_path(result.calendar), notice: "Your demo calendar has been saved!"
      else
        redirect_to demo_root_path, alert: result.errors.join(", ")
      end
    end

    private

    def initialize_demo_calendar
      session[:demo_calendar] ||= {
        "name" => "Your Demo Calendar",
        "color" => "#9B59B6",
        "events" => [],
        "created_at" => Time.current.iso8601
      }
    end

    def demo_calendars_for_display
      Calendar.published.includes(:events).limit(3)
    end

    def demo_events_in_range(start_date, end_date)
      Calendar.published
              .joins(:events)
              .where(events: { starts_at: start_date..end_date })
              .flat_map(&:events)
    end

    def session_events_in_range(start_date, end_date)
      return [] unless session.dig(:demo_calendar, "events")

      session[:demo_calendar]["events"].select do |event|
        starts_at = Time.zone.parse(event["starts_at"]) rescue nil
        next false unless starts_at
        starts_at >= start_date && starts_at <= end_date
      end
    end

    def event_to_json(event)
      if event.is_a?(Hash)
        # Session-based event
        {
          id: event["id"],
          title: event["title"],
          start: event["starts_at"],
          end: event["ends_at"],
          location: event["location"],
          description: event["description"],
          eventType: event["event_type"] || "social",
          creator: "You",
          isDemo: true
        }
      else
        # Database event
        {
          id: event.id,
          title: event.title,
          start: event.starts_at&.iso8601,
          end: event.ends_at&.iso8601,
          location: event.location,
          description: event.description,
          eventType: event.event_type,
          creator: event.calendar&.user&.name || "Demo",
          attendeeCount: event.rsvps.count,
          isDemo: false
        }
      end
    end
  end
end
