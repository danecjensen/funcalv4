module Calendars
  class FromUrlController < ApplicationController
    before_action :authenticate_user!
    before_action :set_calendar, only: [:status, :poll]

    def new
      @url = params[:url]
      @prompt = params[:prompt]
    end

    def create
      url = params[:url].to_s.strip
      prompt = params[:prompt].to_s.strip
      name = params[:name].presence || domain_from_url(url)

      if url.blank?
        redirect_to new_calendars_from_url_path, alert: "Please provide a URL."
        return
      end

      if prompt.blank?
        redirect_to new_calendars_from_url_path(url: url), alert: "Please describe what events to extract."
        return
      end

      @calendar = current_user.calendars.create!(
        name: name,
        import_url: url,
        import_source: "firecrawl",
        extraction_prompt: prompt,
        extraction_status: "pending"
      )

      begin
        FirecrawlExtractJob.perform_later(@calendar.id)
      rescue Redis::CannotConnectError
        FirecrawlExtractJob.perform_now(@calendar.id)
      end

      redirect_to status_calendars_from_url_path(calendar_id: @calendar.id)
    end

    def status
      @poll_url = poll_calendars_from_url_path(calendar_id: @calendar.id, format: :json)
      @calendar_url = calendar_path(@calendar)
    end

    def poll
      @calendar.reload
      events = @calendar.events.order(:starts_at).map do |event|
        {
          id: event.id,
          title: event.title,
          starts_at: event.starts_at&.iso8601,
          ends_at: event.ends_at&.iso8601,
          location: event.location,
          venue: event.venue,
          description: event.description,
          event_type: event.event_type,
          source_url: event.source_url
        }
      end

      render json: {
        status: @calendar.extraction_status,
        event_count: events.size,
        events: events,
        error: @calendar.import_error,
        calendar_name: @calendar.name
      }
    end

    private

    def set_calendar
      @calendar = current_user.calendars.find(params[:calendar_id])
    end

    def domain_from_url(url)
      URI.parse(url).host&.sub(/\Awww\./, "") || "Imported Calendar"
    rescue URI::InvalidURIError
      "Imported Calendar"
    end
  end
end
