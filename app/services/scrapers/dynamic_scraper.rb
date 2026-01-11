# Generic scraper that uses configuration from ScraperSource
# Works with CSS selectors defined in the database
#
# Usage:
#   source = ScraperSource.find_by(slug: 'do512')
#   scraper = Scrapers::DynamicScraper.new(source)
#   events = scraper.scrape
#
module Scrapers
  class DynamicScraper < BaseScraper
    attr_reader :source

    def initialize(source)
      @source = source
    end

    def self.source_name
      "Dynamic"
    end

    def source_name
      @source.name
    end

    def self.calendar_color
      "#3788d8"
    end

    def calendar_color
      @source.color || "#3788d8"
    end

    def scrape
      Rails.logger.info "[#{source_name}] Starting scrape from #{@source.base_url}#{@source.list_path}"

      list_url = @source.full_url(@source.list_path)
      doc = self.class.fetch_page(list_url)

      return [] unless doc

      # Find event links
      event_links = extract_event_links(doc)
      Rails.logger.info "[#{source_name}] Found #{event_links.size} event links"

      events = []
      event_links.each_with_index do |link, index|
        # Rate limiting
        sleep(rand(0.5..1.5)) if index > 0

        event_data = scrape_event_page(link)
        next unless event_data

        saved = save_event(event_data)
        events << saved if saved
      end

      Rails.logger.info "[#{source_name}] Scraped #{events.size} events"
      events
    end

    private

    def extract_event_links(doc)
      links = []
      selector = @source.event_link_selector
      pattern = @source.event_link_pattern

      doc.css(selector).each do |link_el|
        href = link_el["href"]
        next unless href
        next unless href.match?(pattern)

        full_link = @source.full_url(href)
        links << full_link unless links.include?(full_link)
      end

      links.first(50) # Limit to prevent runaway scraping
    end

    def scrape_event_page(url)
      doc = self.class.fetch_page(url)
      return nil unless doc

      title = extract_text(doc, @source.title_selector)
      return nil if title.blank?

      datetime = extract_datetime(doc)
      return nil unless datetime

      {
        title: title.strip,
        starts_at: datetime[:starts_at],
        ends_at: datetime[:ends_at],
        venue: extract_text(doc, @source.venue_selector),
        location: extract_location(doc),
        description: extract_description(doc),
        image_url: extract_image(doc),
        source_url: url,
        all_day: datetime[:all_day] || false
      }
    rescue => e
      Rails.logger.error "[#{source_name}] Error scraping #{url}: #{e.message}"
      nil
    end

    def extract_text(doc, selector)
      return nil unless selector
      el = doc.at_css(selector)
      el&.text&.strip
    end

    def extract_datetime(doc)
      selector = @source.datetime_selector

      # Try datetime attribute first
      datetime_el = doc.at_css("#{selector}[datetime]") || doc.at_css('[datetime]')
      if datetime_el && datetime_el["datetime"].present?
        parsed = Time.zone.parse(datetime_el["datetime"])
        return { starts_at: parsed, ends_at: nil, all_day: false } if parsed
      end

      # Try parsing text content
      time_text = extract_text(doc, selector)
      if time_text.present?
        parsed = self.class.parse_time(time_text)
        return { starts_at: parsed, ends_at: nil, all_day: false } if parsed
      end

      # Try meta tags
      meta_date = doc.at_css('meta[property="event:start_time"], meta[itemprop="startDate"]')
      if meta_date && meta_date["content"].present?
        parsed = Time.zone.parse(meta_date["content"])
        return { starts_at: parsed, ends_at: nil, all_day: false } if parsed
      end

      nil
    end

    def extract_location(doc)
      location = extract_text(doc, @source.location_selector)
      return location if location.present?

      # Try Google Maps link
      maps_link = doc.at_css('a[href*="maps.google.com"], a[href*="goo.gl/maps"]')
      if maps_link
        # Extract address from link text or aria-label
        maps_link.text.strip.presence || maps_link["aria-label"]
      end
    end

    def extract_description(doc)
      selector = @source.description_selector

      # Try getting multiple paragraphs
      elements = doc.css(selector)
      return nil if elements.empty?

      # Get text from first few elements, limiting length
      text = elements.first(3).map(&:text).join("\n\n").strip
      text.truncate(1000) if text.present?
    end

    def extract_image(doc)
      selector = @source.image_selector

      # Try og:image meta tag first
      og_image = doc.at_css('meta[property="og:image"]')
      return og_image["content"] if og_image && og_image["content"].present?

      # Try selector
      img_el = doc.at_css(selector)
      return nil unless img_el

      # Handle both img and meta tags
      src = img_el["src"] || img_el["content"] || img_el["data-src"]
      @source.full_url(src) if src.present?
    end

    # Override save_event to use source configuration
    def save_event(event_data)
      admin = User.find_by(admin: true) || User.first
      unless admin
        Rails.logger.error "[#{source_name}] No admin user available for scraper"
        return nil
      end

      result = EventCreationService.call(
        user: admin,
        params: event_data.merge(
          source_name: source_name,
          calendar_color: calendar_color
        ),
        source: :scraper
      )

      if result.success?
        if result.duplicate?
          Rails.logger.debug "[#{source_name}] Event already exists: #{event_data[:title]}"
        else
          Rails.logger.info "[#{source_name}] Saved event: #{result.event.title}"
        end
        result.event
      else
        Rails.logger.error "[#{source_name}] Failed to save event: #{result.errors.join(', ')}"
        nil
      end
    end
  end
end
