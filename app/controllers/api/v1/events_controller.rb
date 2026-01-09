module Api
  module V1
    class EventsController < BaseController
      def create
        user = api_user
        unless user
          render json: { error: "No user available for event creation" }, status: :unprocessable_entity
          return
        end

        # Create a post with an attached event
        @post = user.posts.build(post_params)

        if @post.save
          render json: {
            success: true,
            event_id: @post.event.id,
            post_id: @post.id,
            event: {
              id: @post.event.id,
              title: @post.event.title,
              starts_at: @post.event.starts_at,
              ends_at: @post.event.ends_at,
              location: @post.event.location,
              all_day: @post.event.all_day
            }
          }, status: :created
        else
          render json: {
            success: false,
            errors: @post.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      def index
        events = Event.includes(:post).order(starts_at: :desc).limit(50)
        render json: events.map { |e|
          {
            id: e.id,
            title: e.title,
            starts_at: e.starts_at,
            ends_at: e.ends_at,
            location: e.location,
            all_day: e.all_day
          }
        }
      end

      private

      def post_params
        {
          body: event_params[:body] || event_params[:title] || "Event from Chrome Extension",
          event_attributes: {
            title: event_params[:title],
            starts_at: parse_datetime(event_params[:starts_at]),
            ends_at: parse_datetime(event_params[:ends_at]),
            location: event_params[:location],
            all_day: event_params[:all_day] || false
          }
        }
      end

      def event_params
        params.require(:event).permit(:title, :starts_at, :ends_at, :location, :all_day, :body, :source_url, :original_text)
      end

      def parse_datetime(value)
        return nil if value.blank?
        Time.zone.parse(value.to_s)
      rescue ArgumentError
        nil
      end
    end
  end
end
