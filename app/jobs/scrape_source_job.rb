# Job to scrape events from a single source
# Handles retries and error reporting
#
# Usage:
#   ScrapeSourceJob.perform_later(source_id)
#   ScrapeSourceJob.perform_later(source.id)
#
class ScrapeSourceJob < ApplicationJob
  queue_as :scrapers

  # Retry with exponential backoff
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # Don't retry on configuration errors
  discard_on ActiveRecord::RecordNotFound

  def perform(source_id)
    source = ScraperSource.find(source_id)

    unless source.enabled?
      Rails.logger.info "[ScrapeSourceJob] Skipping disabled source: #{source.name}"
      return
    end

    Rails.logger.info "[ScrapeSourceJob] Starting scrape for: #{source.name}"

    result = source.run_scraper

    if result[:success]
      Rails.logger.info "[ScrapeSourceJob] Completed scrape for #{source.name}: #{result[:count]} events"
    else
      Rails.logger.error "[ScrapeSourceJob] Failed scrape for #{source.name}: #{result[:error]}"
      # Re-raise to trigger retry
      raise StandardError, result[:error] if result[:error]
    end
  end
end
