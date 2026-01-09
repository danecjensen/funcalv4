module Scrapers
  class AustinChronicleScraper < BaseScraper
    BASE_URL = "https://calendar.austinchronicle.com"
    EVENTS_PAGE = "https://www.austinchronicle.com/events/"

    class << self
      def source_name
        "Austin Chronicle"
      end

      def calendar_color
        "#1a1a2e"
      end

      def scrape
        events = []

        # Fetch from main Austin Chronicle events page
        doc = fetch_page(EVENTS_PAGE)
        return events unless doc

        event_links = extract_event_links(doc)
        Rails.logger.info "[#{source_name}] Found #{event_links.size} event links"

        event_links.first(30).each do |link|
          event_data = scrape_event_page(link)
          if event_data
            saved = save_event(event_data)
            events << saved if saved
          end
        end

        events
      end

      private

      def extract_event_links(doc)
        links = []

        # Look for calendar.austinchronicle.com event links
        doc.css('a[href*="calendar.austinchronicle.com/event/"]').each do |link|
          href = link['href']
          next unless href
          links << href unless links.include?(href)
        end

        links.uniq
      end

      def scrape_event_page(url)
        doc = fetch_page(url)
        return nil unless doc

        # Try JSON-LD first
        json_ld = extract_json_ld(doc)

        title = extract_title(doc, json_ld)
        return nil if title.blank?

        starts_at = extract_datetime(doc, json_ld)
        return nil if starts_at.blank?

        {
          title: title,
          starts_at: starts_at,
          ends_at: nil,
          location: extract_location(doc, json_ld),
          venue: extract_venue(doc, json_ld),
          description: extract_description(doc, json_ld),
          source_url: url,
          image_url: extract_image(doc, json_ld)
        }
      rescue => e
        Rails.logger.error "[#{source_name}] Error scraping #{url}: #{e.message}"
        nil
      end

      def extract_json_ld(doc)
        doc.css('script[type="application/ld+json"]').each do |script|
          begin
            data = JSON.parse(script.text)
            # Check if this is an Event schema
            if data["@type"] == "Event" || (data.is_a?(Array) && data.any? { |d| d["@type"] == "Event" })
              return data.is_a?(Array) ? data.find { |d| d["@type"] == "Event" } : data
            end
          rescue JSON::ParserError
            next
          end
        end
        nil
      end

      def extract_title(doc, json_ld)
        return json_ld["name"] if json_ld && json_ld["name"].present?

        # Try various title selectors
        title = doc.at_css('h1.event-title, h1.title, .event-name h1, .event-header h1')&.text&.strip
        title ||= doc.at_css('h1')&.text&.strip
        title
      end

      def extract_datetime(doc, json_ld)
        # Try JSON-LD first
        if json_ld && json_ld["startDate"]
          return Time.zone.parse(json_ld["startDate"])
        end

        # Look for meta tags
        start_date = doc.at_css('meta[itemprop="startDate"]')&.[]('content')
        return Time.zone.parse(start_date) if start_date.present?

        # Look for datetime elements
        time_el = doc.at_css('time[datetime]')
        return Time.zone.parse(time_el['datetime']) if time_el && time_el['datetime'].present?

        # Try to parse from page content
        doc.css('.event-date, .date, .when, .event-time').each do |el|
          text = el.text.strip
          begin
            return Time.zone.parse(text) if text.present?
          rescue ArgumentError
            next
          end
        end

        nil
      rescue => e
        Rails.logger.warn "[#{source_name}] Could not parse datetime: #{e.message}"
        nil
      end

      def extract_venue(doc, json_ld)
        if json_ld && json_ld["location"]
          loc = json_ld["location"]
          return loc["name"] if loc.is_a?(Hash) && loc["name"].present?
        end

        venue = doc.at_css('.venue-name, .event-venue, .location-name')&.text&.strip
        venue ||= doc.at_css('a[href*="/location/"]')&.text&.strip
        venue
      end

      def extract_location(doc, json_ld)
        if json_ld && json_ld["location"]
          loc = json_ld["location"]
          if loc.is_a?(Hash)
            address = loc["address"]
            if address.is_a?(Hash)
              parts = [
                address["streetAddress"],
                address["addressLocality"],
                address["addressRegion"],
                address["postalCode"]
              ].compact
              return parts.join(", ") if parts.any?
            elsif address.is_a?(String)
              return address
            end
          end
        end

        address = doc.at_css('.venue-address, .event-address, .location-address')&.text&.strip
        address.presence || (extract_venue(doc, json_ld).present? ? "#{extract_venue(doc, json_ld)}, Austin, TX" : "Austin, TX")
      end

      def extract_description(doc, json_ld)
        return json_ld["description"] if json_ld && json_ld["description"].present?

        desc = doc.at_css('.event-description, .event-body, .description, .event-content')&.text&.strip

        if desc.blank?
          doc.css('article p, .event-details p, .content p').each do |p|
            text = p.text.strip
            if text.length > 50 && text.length < 2000
              desc = text
              break
            end
          end
        end

        desc
      end

      def extract_image(doc, json_ld)
        if json_ld && json_ld["image"]
          img = json_ld["image"]
          return img if img.is_a?(String)
          return img["url"] if img.is_a?(Hash) && img["url"]
          return img.first if img.is_a?(Array) && img.first
        end

        og_image = doc.at_css('meta[property="og:image"]')
        return og_image['content'] if og_image && og_image['content'].present?

        img = doc.at_css('.event-image img, article img, .event-photo img')
        img&.[]('src')
      end
    end
  end
end
