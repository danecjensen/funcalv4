module Scrapers
  class Do512Scraper < BaseScraper
    BASE_URL = "https://do512.com"

    class << self
      def source_name
        "Do512"
      end

      def calendar_color
        "#ff6b35"
      end

      def scrape
        events = []
        doc = fetch_page("#{BASE_URL}/events/week")
        return events unless doc

        event_links = extract_event_links(doc)
        Rails.logger.info "[#{source_name}] Found #{event_links.size} event links"

        event_links.each do |link|
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

        doc.css('a[href*="/events/"]').each do |link|
          href = link['href']
          next unless href

          if href.match?(%r{/events/\d{4}/\d{1,2}/\d{1,2}/})
            full_url = href.start_with?('http') ? href : "#{BASE_URL}#{href}"
            links << full_url unless links.include?(full_url)
          end
        end

        links.uniq.first(30)
      end

      def scrape_event_page(url)
        doc = fetch_page(url)
        return nil unless doc

        title = extract_title(doc)
        return nil if title.blank?

        {
          title: title,
          starts_at: extract_datetime(doc),
          ends_at: nil,
          location: extract_location(doc),
          venue: extract_venue(doc),
          description: extract_description(doc),
          source_url: url,
          image_url: extract_image(doc)
        }
      rescue => e
        Rails.logger.error "[#{source_name}] Error scraping #{url}: #{e.message}"
        nil
      end

      def extract_title(doc)
        h1 = doc.at_css('h1')
        return nil unless h1

        title_text = h1.text.strip
        presenter = doc.at_css('h1')&.previous_element
        if presenter && presenter.text.strip.match?(/present/i)
          title_text = "#{presenter.text.strip} #{title_text}"
        end

        title_text.gsub(/\s+/, ' ').strip
      end

      def extract_datetime(doc)
        datetime_el = doc.at_css('[datetime], time[datetime]')
        if datetime_el && datetime_el['datetime']
          return Time.zone.parse(datetime_el['datetime'])
        end

        date_text = doc.css('a[href*="/events/2"]').first&.text&.strip
        time_text = nil

        doc.css('div, span').each do |el|
          text = el.text.strip
          if text.match?(/^\d{1,2}:\d{2}\s*(AM|PM)$/i)
            time_text = text
            break
          end
        end

        if date_text
          date_match = date_text.match(/(\w+)\s+(\w+)\s+(\d{1,2})/)
          if date_match
            month = date_match[2]
            day = date_match[3]
            year = Time.current.year

            datetime_str = "#{month} #{day}, #{year}"
            datetime_str += " #{time_text}" if time_text

            Time.zone.parse(datetime_str)
          end
        end
      rescue => e
        Rails.logger.warn "[#{source_name}] Could not parse datetime: #{e.message}"
        nil
      end

      def extract_venue(doc)
        venue_link = doc.at_css('a[href*="/venues/"]')
        venue_link&.text&.strip
      end

      def extract_location(doc)
        gmap_link = doc.at_css('a[href*="maps.google.com"]')
        if gmap_link
          href = gmap_link['href']
          if href.include?('?q=')
            return URI.decode_www_form_component(href.split('?q=').last.split('&').first)
          end
        end

        venue = extract_venue(doc)
        venue.present? ? "#{venue}, Austin, TX" : "Austin, TX"
      end

      def extract_description(doc)
        desc_candidates = []

        doc.css('p, div').each do |el|
          text = el.text.strip
          if text.length > 50 && text.length < 2000
            next if text.include?("©") || text.include?("cookie")
            next if text.match?(/sign\s*(in|up)/i)
            desc_candidates << text
          end
        end

        desc_candidates.max_by(&:length)
      end

      def extract_image(doc)
        og_image = doc.at_css('meta[property="og:image"]')
        return og_image['content'] if og_image && og_image['content'].present?

        twitter_image = doc.at_css('meta[name="twitter:image"]')
        return twitter_image['content'] if twitter_image && twitter_image['content'].present?

        img = doc.at_css('article img, .event-image img, img[src*="do512"]')
        img&.[]('src')
      end
    end
  end
end
