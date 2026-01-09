module Scrapers
  class BaseScraper
    include HTTParty

    class << self
      def scrape
        raise NotImplementedError, "Subclasses must implement #scrape"
      end

      def source_name
        raise NotImplementedError, "Subclasses must define source_name"
      end

      def create_calendar
        admin = User.find_by(admin: true) || User.first
        return nil unless admin

        Calendar.find_or_create_by!(
          user: admin,
          name: source_name
        ) do |cal|
          cal.description = "Events scraped from #{source_name}"
          cal.color = calendar_color
        end
      end

      def calendar_color
        "#3788d8"
      end

      def save_event(event_data)
        calendar = create_calendar
        return nil unless calendar

        source_id = generate_source_id(event_data)

        existing = Event.find_by(source_name: source_name, source_id: source_id)
        if existing
          Rails.logger.info "[#{source_name}] Event already exists: #{event_data[:title]}"
          return existing
        end

        event = Event.new(
          calendar: calendar,
          title: event_data[:title],
          starts_at: event_data[:starts_at],
          ends_at: event_data[:ends_at],
          location: event_data[:location],
          venue: event_data[:venue],
          description: event_data[:description],
          source_url: event_data[:source_url],
          image_url: event_data[:image_url],
          source_name: source_name,
          source_id: source_id,
          all_day: event_data[:all_day] || false
        )

        if event.save
          Rails.logger.info "[#{source_name}] Saved event: #{event.title}"
          event
        else
          Rails.logger.error "[#{source_name}] Failed to save event: #{event.errors.full_messages.join(', ')}"
          nil
        end
      end

      def generate_source_id(event_data)
        components = [
          event_data[:title].to_s.parameterize,
          event_data[:starts_at]&.to_date&.iso8601
        ].compact.join("-")
        Digest::MD5.hexdigest(components)[0..12]
      end

      def parse_time(date_str, time_str = nil)
        return nil if date_str.blank?

        datetime_str = time_str.present? ? "#{date_str} #{time_str}" : date_str
        Time.zone.parse(datetime_str)
      rescue ArgumentError, TypeError
        nil
      end

      def fetch_page(url, headers: {})
        default_headers = {
          "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
          "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
          "Accept-Language" => "en-US,en;q=0.5"
        }

        response = HTTParty.get(url, headers: default_headers.merge(headers))

        if response.success?
          Nokogiri::HTML(response.body)
        else
          scraper_name = respond_to?(:source_name) ? source_name : self.name
          Rails.logger.error "[#{scraper_name}] Failed to fetch #{url}: #{response.code}"
          nil
        end
      rescue => e
        scraper_name = respond_to?(:source_name) ? source_name : self.name
        Rails.logger.error "[#{scraper_name}] Error fetching #{url}: #{e.message}"
        nil
      end
    end
  end
end
