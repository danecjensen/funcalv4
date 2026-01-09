module Scrapers
  class CulturemapScraper < BaseScraper
    BASE_URL = "https://austin.culturemap.com"

    class << self
      def source_name
        "CultureMap Austin"
      end

      def calendar_color
        "#e63946"
      end

      def scrape
        events = []
        scraped_urls = Set.new

        # Scrape events for this week
        (0..7).each do |days_ahead|
          date = Date.current + days_ahead
          date_tag = date.strftime("%Y%m%d")
          url = "#{BASE_URL}/events?tags=#{date_tag}&time=custom"

          Rails.logger.info "[#{source_name}] Scraping events for #{date}"
          doc = fetch_page(url)
          next unless doc

          event_links = extract_event_links(doc)
          Rails.logger.info "[#{source_name}] Found #{event_links.size} events for #{date}"

          event_links.each do |link|
            next if scraped_urls.include?(link)
            scraped_urls << link

            event_data = scrape_event_page(link, date)
            if event_data
              saved = save_event(event_data)
              events << saved if saved
            end
          end
        end

        events
      end

      private

      def extract_event_links(doc)
        links = []

        doc.css('a[href*="/eventdetail/"]').each do |link|
          href = link['href']
          next unless href

          full_url = href.start_with?('http') ? href : "#{BASE_URL}#{href}"
          links << full_url unless links.include?(full_url)
        end

        links.uniq
      end

      def scrape_event_page(url, target_date = nil)
        doc = fetch_page(url)
        return nil unless doc

        # Try to extract from JSON-LD first
        json_ld = extract_json_ld(doc)

        title = json_ld&.dig("headline") || doc.at_css('h1')&.text&.strip
        return nil if title.blank?

        description = json_ld&.dig("description")
        image_url = extract_image_from_json(json_ld) || extract_image(doc)

        # Parse datetime from JSON-LD keywords
        starts_at = extract_datetime_from_json(json_ld, target_date)

        {
          title: title,
          starts_at: starts_at,
          ends_at: nil,
          location: extract_location(doc),
          venue: extract_venue(doc),
          description: description || extract_description(doc),
          source_url: url,
          image_url: image_url
        }
      rescue => e
        Rails.logger.error "[#{source_name}] Error scraping #{url}: #{e.message}"
        nil
      end

      def extract_json_ld(doc)
        script = doc.at_css('script[type="application/ld+json"]')
        return nil unless script

        JSON.parse(script.text)
      rescue JSON::ParserError
        nil
      end

      def extract_datetime_from_json(json_ld, target_date = nil)
        return nil unless json_ld

        keywords = json_ld["keywords"] || []

        # Look for occurrence patterns like "occurrence202601091930"
        occurrence = keywords.find { |k| k.to_s.start_with?("occurrence") }
        if occurrence
          match = occurrence.match(/occurrence(\d{8})(\d{4})/)
          if match
            date_str = match[1]
            time_str = match[2]
            year = date_str[0..3]
            month = date_str[4..5]
            day = date_str[6..7]
            hour = time_str[0..1]
            minute = time_str[2..3]

            return Time.zone.parse("#{year}-#{month}-#{day} #{hour}:#{minute}")
          end
        end

        # Look for date keywords like "20260109"
        if target_date
          target_tag = target_date.strftime("%Y%m%d")
          if keywords.include?(target_tag)
            # Find corresponding occurrence
            occurrence = keywords.find { |k| k.to_s.start_with?("occurrence#{target_tag}") }
            if occurrence
              match = occurrence.match(/occurrence(\d{8})(\d{4})/)
              if match
                time_str = match[2]
                hour = time_str[0..1]
                minute = time_str[2..3]
                return Time.zone.parse("#{target_date} #{hour}:#{minute}")
              end
            end
            # Default to noon if we have the date but no time
            return Time.zone.parse("#{target_date} 12:00")
          end
        end

        # Fallback: use the first date keyword
        date_keyword = keywords.find { |k| k.to_s.match?(/^\d{8}$/) }
        if date_keyword
          year = date_keyword[0..3]
          month = date_keyword[4..5]
          day = date_keyword[6..7]
          return Time.zone.parse("#{year}-#{month}-#{day} 12:00")
        end

        nil
      rescue => e
        Rails.logger.warn "[#{source_name}] Could not parse datetime from JSON-LD: #{e.message}"
        nil
      end

      def extract_image_from_json(json_ld)
        return nil unless json_ld

        images = json_ld["image"]
        return nil unless images.is_a?(Array) && images.any?

        # Get the first/primary image
        first_image = images.first
        if first_image.is_a?(Hash)
          first_image["url"]
        elsif first_image.is_a?(String)
          first_image
        end
      end

      def extract_venue(doc)
        # Look for venue name in specific location section
        doc.css('article div, div.venue').each do |el|
          text = el.text.strip
          # Skip if it contains the full address
          next if text.include?(',') && text.match?(/\d{4,}/)
          next if text.length > 100
          next if text.length < 3

          # Look for venue-like text patterns
          if el.previous_element&.text&.include?('WHERE') ||
             el.parent&.text&.include?('WHERE')
            lines = text.split("\n").map(&:strip).reject(&:blank?)
            return lines.first if lines.first && lines.first.length < 100
          end
        end
        nil
      end

      def extract_location(doc)
        # Look for full address
        doc.css('article div, div').each do |el|
          text = el.text.strip
          # Address pattern: number + street + city/state
          if text.match?(/\d+\s+[\w\s]+,\s*[\w\s]+,\s*[A-Z]{2}\s*\d{5}/i)
            match = text.match(/(\d+\s+[\w\s]+,\s*[\w\s]+,\s*[A-Z]{2}\s*\d{5}[\w\s,-]*)/i)
            return match[1].strip if match
          end
        end

        venue = extract_venue(doc)
        venue.present? ? "#{venue}, Austin, TX" : "Austin, TX"
      end

      def extract_description(doc)
        # Look for description paragraphs
        doc.css('article p').each do |p|
          text = p.text.strip
          if text.length > 50 && text.length < 2000
            next if text.include?("©")
            next if text.match?(/subscribe|email|newsletter/i)
            return text
          end
        end
        nil
      end

      def extract_image(doc)
        # Look for og:image first
        og_image = doc.at_css('meta[property="og:image"]')
        return og_image['content'] if og_image && og_image['content'].present?

        # Look for main article image
        img = doc.at_css('article img[src*="cloudinary"], article img[src*="culturemap"]')
        img&.[]('src')
      end
    end
  end
end
