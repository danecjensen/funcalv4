class CalendarController < ApplicationController
  before_action :authenticate_user!
  before_action :set_calendar, only: [:show, :edit, :update, :generate_ical_token]

  def index
  end

  def edit
    authorize @calendar
    @scrapers = @calendar.scraper_sources.order(:name)
  end

  def update
    authorize @calendar
    if @calendar.update(calendar_params)
      redirect_to edit_calendar_path(@calendar), notice: "Calendar updated!"
    else
      @scrapers = @calendar.scraper_sources.order(:name)
      render :edit, status: :unprocessable_entity
    end
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
    # @calendar is set by before_action
  end

  def create
    @calendar = current_user.calendars.build(calendar_params)
    @calendar.name ||= "My Calendar #{current_user.calendars.count + 1}"

    if @calendar.save
      redirect_to calendar_path(@calendar), notice: "Calendar created!"
    else
      redirect_to root_path, alert: @calendar.errors.full_messages.join(", ")
    end
  end

  def generate_ical_token
    authorize @calendar, :update?
    @calendar.regenerate_ical_token!
    redirect_to edit_calendar_path(@calendar), notice: "iCal feed URL regenerated!"
  end

  private

  def set_calendar
    @calendar = Calendar.find(params[:id])
  end

  def calendar_params
    params.fetch(:calendar, {}).permit(
      :name, :color, :description,
      :import_url, :import_source, :import_enabled, :import_interval_hours
    )
  end

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
