module Scrapers
  class EventScraperService
    SCRAPERS = [
      Do512Scraper,
      CulturemapScraper,
      AustinChronicleScraper
    ].freeze

    class << self
      def scrape_all
        results = {}

        SCRAPERS.each do |scraper|
          Rails.logger.info "Starting #{scraper.source_name} scraper..."
          begin
            events = scraper.scrape
            results[scraper.source_name] = {
              success: true,
              count: events.size,
              events: events
            }
            Rails.logger.info "#{scraper.source_name}: Scraped #{events.size} events"
          rescue => e
            Rails.logger.error "#{scraper.source_name} failed: #{e.message}"
            Rails.logger.error e.backtrace.first(5).join("\n")
            results[scraper.source_name] = {
              success: false,
              error: e.message
            }
          end
        end

        # Run deduplication
        deduplicate_events

        results
      end

      def scrape(source_name)
        scraper = SCRAPERS.find { |s| s.source_name.downcase == source_name.downcase }
        raise ArgumentError, "Unknown scraper: #{source_name}" unless scraper

        scraper.scrape
      end

      def deduplicate_events
        Rails.logger.info "Running event deduplication..."

        # Find potential duplicates based on title similarity and date
        duplicates_removed = 0

        Event.where.not(source_name: nil).group_by { |e| e.starts_at&.to_date }.each do |date, events|
          next if events.size < 2

          events.combination(2).each do |e1, e2|
            if similar_events?(e1, e2)
              # Keep the one with more data, remove the other
              keeper, duplicate = [e1, e2].sort_by { |e| event_data_score(e) }.reverse

              Rails.logger.info "Removing duplicate: '#{duplicate.title}' (keeping '#{keeper.title}')"
              duplicate.destroy
              duplicates_removed += 1
            end
          end
        end

        Rails.logger.info "Deduplication complete. Removed #{duplicates_removed} duplicates."
        duplicates_removed
      end

      private

      def similar_events?(e1, e2)
        return false if e1.id == e2.id
        return false if e1.source_name == e2.source_name && e1.source_id == e2.source_id

        # Normalize titles for comparison
        t1 = normalize_title(e1.title)
        t2 = normalize_title(e2.title)

        # Check if titles are very similar
        similarity = string_similarity(t1, t2)
        return true if similarity > 0.85

        # Check if one title contains the other
        return true if t1.include?(t2) || t2.include?(t1)

        # Check venue + date match with partial title match
        if e1.venue.present? && e2.venue.present?
          venue_match = normalize_title(e1.venue) == normalize_title(e2.venue)
          date_match = e1.starts_at&.to_date == e2.starts_at&.to_date
          title_partial = similarity > 0.6

          return true if venue_match && date_match && title_partial
        end

        false
      end

      def normalize_title(title)
        return "" if title.blank?
        title.downcase
             .gsub(/[^\w\s]/, '')  # Remove punctuation
             .gsub(/\s+/, ' ')     # Normalize whitespace
             .gsub(/\b(the|a|an|at|in|on|for|and|or|with|w\/|feat|featuring|presents?)\b/, '')
             .strip
      end

      def string_similarity(s1, s2)
        return 1.0 if s1 == s2
        return 0.0 if s1.blank? || s2.blank?

        # Use Jaccard similarity on word sets
        words1 = s1.split.to_set
        words2 = s2.split.to_set

        intersection = (words1 & words2).size
        union = (words1 | words2).size

        return 0.0 if union == 0
        intersection.to_f / union
      end

      def event_data_score(event)
        score = 0
        score += 1 if event.title.present?
        score += 1 if event.description.present?
        score += 2 if event.description.to_s.length > 100
        score += 1 if event.venue.present?
        score += 1 if event.location.present?
        score += 1 if event.image_url.present?
        score += 1 if event.source_url.present?
        score
      end
    end
  end
end
