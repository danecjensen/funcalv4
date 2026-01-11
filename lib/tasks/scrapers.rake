namespace :scrapers do
  desc "Load scraper sources from YAML configuration"
  task load: :environment do
    ScraperSource.load_from_yaml
    puts "Loaded #{ScraperSource.count} scraper sources"
  end

  desc "Run all enabled scrapers"
  task scrape_all: :environment do
    sources = ScraperSource.enabled
    puts "Scraping #{sources.count} sources..."

    sources.find_each do |source|
      puts "\nScraping #{source.name}..."
      result = source.run_scraper

      if result[:success]
        puts "  Success: #{result[:count]} events"
      else
        puts "  Error: #{result[:error]}"
      end
    end
  end

  desc "Run a specific scraper by slug"
  task :scrape, [:slug] => :environment do |_t, args|
    source = ScraperSource.find_by(slug: args[:slug])

    if source.nil?
      puts "Source not found: #{args[:slug]}"
      puts "Available sources: #{ScraperSource.pluck(:slug).join(', ')}"
      exit 1
    end

    puts "Scraping #{source.name}..."
    result = source.run_scraper

    if result[:success]
      puts "Success: #{result[:count]} events"
    else
      puts "Error: #{result[:error]}"
    end
  end

  desc "List all scraper sources and their status"
  task status: :environment do
    puts "\nScraper Sources:"
    puts "-" * 80

    ScraperSource.all.each do |source|
      status = source.enabled? ? "enabled" : "disabled"
      last_run = source.last_run_at&.strftime("%Y-%m-%d %H:%M") || "never"
      error = source.last_error.present? ? " [ERROR]" : ""

      printf "%-20s %-10s Last run: %-20s Events: %d%s\n",
             source.name,
             status,
             last_run,
             source.total_events_scraped,
             error
    end
  end

  desc "Enable a scraper source"
  task :enable, [:slug] => :environment do |_t, args|
    source = ScraperSource.find_by!(slug: args[:slug])
    source.update!(enabled: true)
    puts "Enabled #{source.name}"
  end

  desc "Disable a scraper source"
  task :disable, [:slug] => :environment do |_t, args|
    source = ScraperSource.find_by!(slug: args[:slug])
    source.update!(enabled: false)
    puts "Disabled #{source.name}"
  end
end
