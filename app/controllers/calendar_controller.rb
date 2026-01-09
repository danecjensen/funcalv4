class CalendarController < ApplicationController
  before_action :authenticate_user!

  def index
  end

  def events
    start_date = Date.parse(params[:start])
    end_date = Date.parse(params[:end])

    @events = Event.includes(post: :creator).in_range(start_date, end_date)

    render json: @events.map { |e| event_json(e) }
  end

  def show
    @event = Event.includes(post: [:creator, :comments, :likes]).find(params[:id])
  end

  private

  def event_json(event)
    {
      id: event.id,
      title: event.title,
      start: event.starts_at.iso8601,
      end: event.ends_at&.iso8601,
      allDay: event.all_day,
      extendedProps: {
        location: event.location,
        postId: event.post_id
      }
    }
  end
end
