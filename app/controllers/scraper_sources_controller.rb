class ScraperSourcesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_calendar
  before_action :set_scraper_source, only: [:update, :destroy, :run]

  def create
    authorize @calendar, :update?
    @scraper_source = @calendar.scraper_sources.build(scraper_source_params)
    @scraper_source.slug = @scraper_source.name.parameterize if @scraper_source.slug.blank?

    if @scraper_source.save
      redirect_to edit_calendar_path(@calendar, anchor: "scrapers"), notice: "Scraper added!"
    else
      redirect_to edit_calendar_path(@calendar, anchor: "scrapers"), alert: @scraper_source.errors.full_messages.join(", ")
    end
  end

  def update
    authorize @calendar, :update?
    if @scraper_source.update(scraper_source_params)
      redirect_to edit_calendar_path(@calendar, anchor: "scrapers"), notice: "Scraper updated!"
    else
      redirect_to edit_calendar_path(@calendar, anchor: "scrapers"), alert: @scraper_source.errors.full_messages.join(", ")
    end
  end

  def destroy
    authorize @calendar, :update?
    @scraper_source.destroy
    redirect_to edit_calendar_path(@calendar, anchor: "scrapers"), notice: "Scraper removed."
  end

  def run
    authorize @calendar, :update?
    ScrapeSourceJob.perform_later(@scraper_source.id)
    redirect_to edit_calendar_path(@calendar, anchor: "scrapers"), notice: "Scraper started! Events will appear shortly."
  end

  private

  def set_calendar
    @calendar = Calendar.find(params[:calendar_id])
  end

  def set_scraper_source
    @scraper_source = @calendar.scraper_sources.find(params[:id])
  end

  def scraper_source_params
    params.require(:scraper_source).permit(
      :name, :base_url, :list_path, :color, :enabled,
      selectors: [:event_links, :event_link_pattern, :title, :datetime, :venue, :location, :description, :image],
      schedule: [:interval_hours, :cron]
    )
  end
end
