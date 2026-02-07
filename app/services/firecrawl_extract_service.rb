class FirecrawlExtractService
  FIRECRAWL_API_URL = "https://api.firecrawl.dev/v1/scrape".freeze
  DEFAULT_DAYS_AHEAD = 8

  Result = Struct.new(:success?, :events, :error, keyword_init: true) do
    def success? = self[:success?]
  end

  def self.call(**args)
    new(**args).call
  end

  def initialize(url:, prompt:)
    @url = url
    @prompt = prompt
  end

  def call
    response = HTTParty.post(
      FIRECRAWL_API_URL,
      headers: {
        "Authorization" => "Bearer #{api_key}",
        "Content-Type" => "application/json"
      },
      body: request_body.to_json,
      timeout: 60
    )

    parse_response(response)
  rescue HTTParty::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError => e
    Result.new(success?: false, events: [], error: "Request failed: #{e.message}")
  end

  private

  def api_key
    ENV.fetch("FIRECRAWL_API_KEY") { raise "FIRECRAWL_API_KEY not set" }
  end

  def request_body
    {
      url: @url,
      formats: ["extract"],
      onlyMainContent: true,
      extract: {
        prompt: extraction_prompt,
        schema: event_schema
      },
      timeout: 30000
    }
  end

  def extraction_prompt
    range = date_range_from_prompt
    today_str = Date.current.strftime("%A, %B %-d, %Y")

    "Today is #{today_str}. " \
    "Extract all events from this webpage that match: #{@prompt}. " \
    "Only include events occurring between #{range[:from].strftime('%B %-d, %Y')} and #{range[:to].strftime('%B %-d, %Y')} (inclusive). " \
    "For each event, extract the title, start date/time in ISO 8601 format, " \
    "end date/time if available, location, venue name, a brief description (1-2 sentences), " \
    "and categorize as: social, meeting, workshop, community, or celebration. " \
    "If the year is not specified, assume #{Date.current.year}. " \
    "Skip any events outside the date range."
  end

  def date_range_from_prompt
    today = Date.current
    text = @prompt.downcase

    # "this weekend"
    if text.match?(/this\s+weekend/)
      saturday = today + ((6 - today.wday) % 7)
      saturday = today if today.saturday? || today.sunday?
      return { from: saturday, to: saturday + 1 }
    end

    # "next weekend"
    if text.match?(/next\s+weekend/)
      days_until_sat = (6 - today.wday) % 7
      days_until_sat = 7 if days_until_sat == 0
      saturday = today + days_until_sat + 7
      return { from: saturday, to: saturday + 1 }
    end

    # "next week"
    if text.match?(/next\s+week/)
      monday = today + ((1 - today.wday) % 7) + 7
      return { from: monday, to: monday + 6 }
    end

    # "this week"
    if text.match?(/this\s+week/)
      return { from: today, to: today + (6 - today.wday) }
    end

    # "next N days" or "next N days"
    if (m = text.match(/next\s+(\d+)\s+days?/))
      return { from: today, to: today + m[1].to_i }
    end

    # "this month"
    if text.match?(/this\s+month/)
      return { from: today, to: today.end_of_month }
    end

    # "next month"
    if text.match?(/next\s+month/)
      start = (today + 1.month).beginning_of_month
      return { from: start, to: start.end_of_month }
    end

    # Explicit date range: "feb 10 - feb 15", "february 10-15", "2/10 - 2/15"
    if (m = text.match(/(\w+\s+\d{1,2})\s*[-–to]+\s*(\w+\s+\d{1,2})/))
      from = parse_fuzzy_date(m[1])
      to = parse_fuzzy_date(m[2])
      return { from: from, to: to } if from && to
    end

    # Single month mention: "in february", "in march"
    if (m = text.match(/\bin\s+(january|february|march|april|may|june|july|august|september|october|november|december)\b/))
      month_num = Date::MONTHNAMES.index(m[1].capitalize)
      if month_num
        start = Date.new(today.year, month_num, 1)
        start = start >> 12 if start < today - 30
        return { from: [start, today].max, to: start.end_of_month }
      end
    end

    # Default: today + 8 days
    { from: today, to: today + DEFAULT_DAYS_AHEAD }
  end

  def parse_fuzzy_date(str)
    Date.parse(str)
  rescue Date::Error, ArgumentError
    nil
  end

  def event_schema
    {
      type: "object",
      properties: {
        events: {
          type: "array",
          items: {
            type: "object",
            properties: {
              title: { type: "string" },
              starts_at: { type: "string", description: "ISO 8601 datetime" },
              ends_at: { type: "string", description: "ISO 8601 datetime, if available" },
              location: { type: "string" },
              venue: { type: "string" },
              description: { type: "string", description: "Brief description, 1-2 sentences" },
              event_type: { type: "string", enum: %w[social meeting workshop community celebration] },
              image_url: { type: "string" },
              source_url: { type: "string", description: "Direct URL to the event page if available" }
            },
            required: %w[title starts_at]
          }
        }
      },
      required: %w[events]
    }
  end

  def parse_response(response)
    unless response.success?
      error_msg = response.parsed_response&.dig("error") || "HTTP #{response.code}"
      return Result.new(success?: false, events: [], error: error_msg)
    end

    data = response.parsed_response
    unless data&.dig("success")
      return Result.new(success?: false, events: [], error: data&.dig("error") || "Extraction failed")
    end

    events = data.dig("data", "extract", "events") || []
    Result.new(success?: true, events: events, error: nil)
  rescue JSON::ParserError => e
    Result.new(success?: false, events: [], error: "Failed to parse response: #{e.message}")
  end
end
