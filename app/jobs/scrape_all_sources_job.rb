# Job to scrape all enabled sources
# Schedules individual ScrapeSourceJob for each source
#
# Usage:
#   ScrapeAllSourcesJob.perform_later
#
# Scheduled via sidekiq-scheduler to run every 4 hours
#
class ScrapeAllSourcesJob < ApplicationJob
  queue_as :scrapers

  def perform
    sources = ScraperSource.enabled

    if sources.empty?
      Rails.logger.info "[ScrapeAllSourcesJob] No enabled sources to scrape"
      return
    end

    Rails.logger.info "[ScrapeAllSourcesJob] Queueing #{sources.count} sources for scraping"

    sources.find_each do |source|
      # Stagger jobs to avoid overwhelming external sites
      ScrapeSourceJob.set(wait: rand(0..60).seconds).perform_later(source.id)
    end
  end
end
