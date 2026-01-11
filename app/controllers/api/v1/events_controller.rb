module Api
  module V1
    class EventsController < BaseController
      def create
        user = api_user
        unless user
          render json: { error: "No user available for event creation" }, status: :unprocessable_entity
          return
        end

        result = EventCreationService.call(
          user: user,
          params: event_params,
          source: :api
        )

        if result.success?
          render json: {
            success: true,
            event_id: result.event.id,
            post_id: result.post&.id,
            duplicate: result.duplicate?,
            event: event_json(result.event)
          }, status: :created
        else
          render json: {
            success: false,
            errors: result.errors
          }, status: :unprocessable_entity
        end
      end

      def index
        events = policy_scope(Event).includes(:post, :calendar).order(starts_at: :desc)

        # Filter by date range if provided
        if params[:start].present? && params[:end].present?
          events = events.in_range(Date.parse(params[:start]), Date.parse(params[:end]))
        end

        # Filter by calendar if provided
        events = events.where(calendar_id: params[:calendar_id]) if params[:calendar_id].present?

        # Search by keyword
        events = events.where("title ILIKE ?", "%#{params[:q]}%") if params[:q].present?

        events = events.limit(params[:limit] || 50)

        render json: events.map { |e| event_json(e) }
      end

      def show
        event = Event.find(params[:id])
        authorize event
        render json: event_json(event)
      end

      def update
        event = Event.find(params[:id])
        authorize event

        if event.update(update_params)
          render json: event_json(event)
        else
          render json: { errors: event.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        event = Event.find(params[:id])
        authorize event
        event.destroy
        head :no_content
      end

      # GET /api/v1/events/search?q=keyword&start=2024-01-01&end=2024-12-31
      def search
        events = policy_scope(Event).includes(:post, :calendar)

        if params[:q].present?
          events = events.where("title ILIKE :q OR description ILIKE :q OR venue ILIKE :q OR location ILIKE :q",
                                q: "%#{params[:q]}%")
        end

        if params[:start].present? && params[:end].present?
          events = events.in_range(Date.parse(params[:start]), Date.parse(params[:end]))
        elsif params[:start].present?
          events = events.where("starts_at >= ?", Date.parse(params[:start]))
        elsif params[:end].present?
          events = events.where("starts_at <= ?", Date.parse(params[:end]))
        end

        events = events.where(calendar_id: params[:calendar_id]) if params[:calendar_id].present?
        events = events.where(event_type: params[:event_type]) if params[:event_type].present?

        events = events.order(starts_at: :asc).limit(params[:limit] || 50)

        render json: {
          query: params[:q],
          count: events.size,
          events: events.map { |e| event_json(e) }
        }
      end

      private

      def event_params
        params.require(:event).permit(
          :title, :starts_at, :ends_at, :location, :all_day,
          :body, :description, :source_url, :original_text,
          :event_type, :venue, :calendar_id
        )
      end

      def update_params
        params.require(:event).permit(
          :title, :starts_at, :ends_at, :location, :all_day,
          :description, :event_type, :venue
        )
      end

      def event_json(event)
        {
          id: event.id,
          title: event.title,
          starts_at: event.starts_at&.iso8601,
          ends_at: event.ends_at&.iso8601,
          location: event.location,
          venue: event.venue,
          description: event.description,
          all_day: event.all_day,
          event_type: event.event_type,
          source_url: event.source_url,
          calendar_id: event.calendar_id,
          creator: event.post&.creator&.display_name,
          created_at: event.created_at&.iso8601
        }
      end
    end
  end
end
