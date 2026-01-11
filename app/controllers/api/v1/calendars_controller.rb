module Api
  module V1
    class CalendarsController < BaseController
      def index
        calendars = policy_scope(Calendar).includes(:user, :events)

        render json: calendars.map { |c| calendar_json(c) }
      end

      def show
        calendar = Calendar.find(params[:id])
        authorize calendar

        render json: calendar_json(calendar, include_events: true)
      end

      private

      def calendar_json(calendar, include_events: false)
        data = {
          id: calendar.id,
          name: calendar.name,
          description: calendar.description,
          color: calendar.color,
          owner: calendar.user&.display_name,
          published: calendar.published?,
          event_count: calendar.events.count,
          created_at: calendar.created_at&.iso8601
        }

        if include_events
          data[:events] = calendar.events.order(starts_at: :asc).limit(100).map do |e|
            {
              id: e.id,
              title: e.title,
              starts_at: e.starts_at&.iso8601,
              ends_at: e.ends_at&.iso8601,
              location: e.location,
              all_day: e.all_day
            }
          end
        end

        data
      end
    end
  end
end
