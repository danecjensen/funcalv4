# Database-driven scraper configuration
# Allows adding/removing event sources without code changes
#
# Usage:
#   source = ScraperSource.find_by(slug: 'do512')
#   source.run_scraper  # Runs the scraper and saves events
#
class ScraperSource < ApplicationRecord
  belongs_to :calendar, optional: true

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :calendar_id }
  validates :base_url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
  validates :color, format: { with: /\A#[0-9A-Fa-f]{6}\z/, message: "must be a valid hex color" }, allow_blank: true

  scope :enabled, -> { where(enabled: true) }
  scope :due_for_scrape, -> {
    enabled.where("last_run_at IS NULL OR last_run_at < ?", 4.hours.ago)
  }

  # Run the scraper for this source
  def run_scraper
    scraper = scraper_instance
    return { success: false, error: "No scraper available" } unless scraper

    begin
      events = scraper.scrape
      event_count = events.compact.size

      update!(
        last_run_at: Time.current,
        last_success_at: Time.current,
        last_run_count: event_count,
        total_events_scraped: total_events_scraped + event_count,
        last_error: nil
      )

      { success: true, count: event_count }
    rescue => e
      update!(
        last_run_at: Time.current,
        last_error: "#{e.class}: #{e.message}"
      )

      Rails.logger.error "[#{name}] Scraper error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      { success: false, error: e.message }
    end
  end

  # Get the scraper instance for this source
  def scraper_instance
    if scraper_class.present?
      # Use a custom scraper class
      klass = "Scrapers::#{scraper_class}".constantize
      klass.new(self) if klass.respond_to?(:new)
    else
      # Use the dynamic scraper with config from selectors
      Scrapers::DynamicScraper.new(self)
    end
  rescue NameError => e
    Rails.logger.error "[#{name}] Invalid scraper class: #{scraper_class} - #{e.message}"
    nil
  end

  # Schedule configuration helpers
  def cron_expression
    schedule.dig("cron")
  end

  def scrape_interval_hours
    schedule.dig("interval_hours") || 4
  end

  # Selector helpers with defaults
  def selector_for(key)
    selectors.dig(key.to_s)
  end

  def event_link_selector
    selector_for(:event_links) || 'a[href*="/event"]'
  end

  def event_link_pattern
    Regexp.new(selector_for(:event_link_pattern) || '/events?/')
  end

  def title_selector
    selector_for(:title) || "h1"
  end

  def datetime_selector
    selector_for(:datetime) || '[datetime], time[datetime], .date, .time'
  end

  def venue_selector
    selector_for(:venue) || '.venue, [itemprop="location"]'
  end

  def location_selector
    selector_for(:location) || '.address, [itemprop="address"]'
  end

  def description_selector
    selector_for(:description) || '.description, [itemprop="description"], p'
  end

  def image_selector
    selector_for(:image) || 'meta[property="og:image"], img.event-image, .event-img img'
  end

  # Full URL helper
  def full_url(path)
    return path if path&.start_with?("http")
    URI.join(base_url, path || "").to_s
  end

  # Class method to load from YAML config
  def self.load_from_yaml(file_path = Rails.root.join("config/scrapers/sources.yml"))
    return unless File.exist?(file_path)

    sources = YAML.load_file(file_path)
    sources.each do |slug, config|
      find_or_initialize_by(slug: slug).tap do |source|
        source.assign_attributes(
          name: config["name"],
          base_url: config["base_url"],
          list_path: config["list_path"],
          scraper_class: config["scraper_class"],
          selectors: config["selectors"] || {},
          schedule: config["schedule"] || {},
          color: config["color"] || "#3788d8",
          enabled: config.fetch("enabled", true)
        )
        source.save!
        Rails.logger.info "Loaded scraper source: #{source.name}"
      end
    end
  end
end
