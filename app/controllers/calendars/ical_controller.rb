require "icalendar"

module Calendars
  class IcalController < ApplicationController
    skip_before_action :authenticate_user!

    # GET /calendars/:ical_token.ics
    def show
      @calendar = Calendar.find_by!(ical_token: params[:ical_token])

      respond_to do |format|
        format.ics do
          cal = build_icalendar(@calendar)
          render plain: cal.to_ical, content_type: "text/calendar"
        end
      end
    end

    # POST /calendars/:id/generate_ical_token
    def generate_token
      @calendar = Calendar.find(params[:calendar_id])
      authorize @calendar, :update?

      @calendar.regenerate_ical_token!

      respond_to do |format|
        format.html { redirect_to @calendar, notice: "iCal feed URL generated" }
        format.json { render json: { ical_url: calendar_ical_url(@calendar) } }
      end
    end

    private

    def build_icalendar(calendar)
      cal = Icalendar::Calendar.new
      cal.prodid = "-//FunCal//Calendar//EN"
      cal.x_wr_calname = calendar.name

      calendar.events.each do |event|
        cal.event do |e|
          e.uid = "event-#{event.id}@funcal"
          e.dtstart = format_datetime(event.starts_at, event.all_day)
          e.dtend = format_datetime(event.ends_at || event.starts_at + 1.hour, event.all_day)
          e.summary = event.title
          e.description = event.description if event.description.present?
          e.location = [event.venue, event.location].compact.join(", ") if event.venue.present? || event.location.present?
          e.url = event.source_url if event.source_url.present?
          e.created = event.created_at
          e.last_modified = event.updated_at
          e.categories = [event.event_type.upcase] if event.event_type.present?
        end
      end

      cal.publish
      cal
    end

    def format_datetime(datetime, all_day)
      return nil unless datetime

      if all_day
        Icalendar::Values::Date.new(datetime.to_date)
      else
        Icalendar::Values::DateTime.new(datetime.utc, "tzid" => "UTC")
      end
    end

    def calendar_ical_url(calendar)
      calendar_ical_feed_url(ical_token: calendar.ical_token, format: :ics)
    end
    helper_method :calendar_ical_url
  end
end
