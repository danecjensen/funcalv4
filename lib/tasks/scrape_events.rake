namespace :events do
  desc "Scrape events from all configured sources"
  task scrape_all: :environment do
    puts "Starting event scraper..."
    results = Scrapers::EventScraperService.scrape_all

    puts "\n=== Scraping Results ==="
    results.each do |source, result|
      if result[:success]
        puts "#{source}: ✓ #{result[:count]} events scraped"
      else
        puts "#{source}: ✗ Failed - #{result[:error]}"
      end
    end

    total = results.values.select { |r| r[:success] }.sum { |r| r[:count] }
    puts "\nTotal events scraped: #{total}"
  end

  desc "Scrape events from Do512"
  task scrape_do512: :environment do
    puts "Scraping Do512..."
    events = Scrapers::Do512Scraper.scrape
    puts "Scraped #{events.size} events from Do512"
  end

  desc "Scrape events from CultureMap Austin"
  task scrape_culturemap: :environment do
    puts "Scraping CultureMap Austin..."
    events = Scrapers::CulturemapScraper.scrape
    puts "Scraped #{events.size} events from CultureMap Austin"
  end

  desc "Scrape events from Austin Chronicle"
  task scrape_chronicle: :environment do
    puts "Scraping Austin Chronicle..."
    events = Scrapers::AustinChronicleScraper.scrape
    puts "Scraped #{events.size} events from Austin Chronicle"
  end

  desc "Remove duplicate events"
  task deduplicate: :environment do
    puts "Running event deduplication..."
    removed = Scrapers::EventScraperService.deduplicate_events
    puts "Removed #{removed} duplicate events"
  end

  desc "Show scraped event statistics"
  task stats: :environment do
    puts "\n=== Event Statistics ==="

    total = Event.count
    puts "Total events: #{total}"

    Event.group(:source_name).count.each do |source, count|
      source_name = source || "Manual/API"
      puts "  #{source_name}: #{count}"
    end

    upcoming = Event.where("starts_at >= ?", Time.current).count
    puts "\nUpcoming events: #{upcoming}"

    this_week = Event.where(starts_at: Time.current..1.week.from_now).count
    puts "This week: #{this_week}"
  end
end
