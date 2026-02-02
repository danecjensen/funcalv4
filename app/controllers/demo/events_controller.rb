module Demo
  class EventsController < ApplicationController
    # No authentication required for demo pages

    MAX_DEMO_EVENTS = 50

    def create
      initialize_demo_calendar

      if session[:demo_calendar]["events"].size >= MAX_DEMO_EVENTS
        render json: { error: "Demo calendar is limited to #{MAX_DEMO_EVENTS} events. Sign up to create more!" }, status: :unprocessable_entity
        return
      end

      event_params = params.require(:event).permit(:title, :starts_at, :ends_at, :location, :description, :event_type)

      event = {
        "id" => SecureRandom.uuid,
        "title" => event_params[:title],
        "starts_at" => normalize_time(event_params[:starts_at]),
        "ends_at" => normalize_time(event_params[:ends_at]) || default_end_time(event_params[:starts_at]),
        "location" => event_params[:location],
        "description" => event_params[:description],
        "event_type" => event_params[:event_type] || "social",
        "created_at" => Time.current.iso8601
      }

      session[:demo_calendar]["events"] << event

      render json: {
        id: event["id"],
        title: event["title"],
        start: event["starts_at"],
        end: event["ends_at"],
        location: event["location"],
        description: event["description"],
        eventType: event["event_type"],
        creator: "You",
        isDemo: true
      }, status: :created
    end

    def destroy
      initialize_demo_calendar

      session[:demo_calendar]["events"].reject! { |e| e["id"] == params[:id] }

      head :no_content
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

    def normalize_time(time_string)
      return nil if time_string.blank?

      time = Time.zone.parse(time_string) rescue nil
      return nil unless time

      # Normalize to nearest :00 or :30
      minutes = time.min
      normalized_minutes = if minutes < 15
                             0
                           elsif minutes < 45
                             30
                           else
                             0
                           end

      if minutes >= 45
        time.change(min: 0, sec: 0) + 1.hour
      else
        time.change(min: normalized_minutes, sec: 0)
      end.iso8601
    end

    def default_end_time(starts_at)
      return nil if starts_at.blank?

      time = Time.zone.parse(starts_at) rescue nil
      return nil unless time

      (time + 1.hour).iso8601
    end
  end
end
