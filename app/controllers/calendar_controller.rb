class CalendarController < ApplicationController
  before_action :authenticate_user!

  def index
  end

  def events
    start_date = Date.parse(params[:start])
    end_date = Date.parse(params[:end])

    @events = Event.includes(post: :creator).in_range(start_date, end_date)

    # Filter by calendar if calendar_id is provided
    if params[:calendar_id].present?
      @events = @events.where(calendar_id: params[:calendar_id])
    end

    render json: @events.map { |e| event_json(e) }
  end

  def show
    @calendar = Calendar.find(params[:id])
  end

  def create
    result = EventCreationService.call(
      user: current_user,
      params: event_params,
      source: :manual
    )

    if result.success?
      render json: event_json(result.event), status: :created
    else
      render json: { message: result.errors.join(", ") }, status: :unprocessable_entity
    end
  end

  private

  def event_params
    params.require(:event).permit(:title, :event_type, :starts_at, :location, :description, :calendar_id)
  end

  def event_json(event)
    {
      id: event.id,
      title: event.title,
      start: event.starts_at.iso8601,
      end: event.ends_at&.iso8601,
      allDay: event.all_day,
      eventType: event.event_type,
      location: event.location,
      description: event.post&.body&.to_plain_text,
      creator: event.post&.creator&.display_name,
      createdAt: event.created_at&.iso8601,
      attendeeCount: 1
    }
  end
end
