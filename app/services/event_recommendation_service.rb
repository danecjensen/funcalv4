# Service to recommend events based on user preferences and history
#
# Usage:
#   service = EventRecommendationService.new(user)
#   recommendations = service.recommend(limit: 10)
#
# The service considers:
# - Event types the user has created or attended
# - Venues the user has visited
# - Day of week and time preferences
# - Events from subscribed calendars
# - Popular events in the community
#
class EventRecommendationService
  Recommendation = Struct.new(:event, :score, :reasons, keyword_init: true)

  def initialize(user)
    @user = user
  end

  def recommend(limit: 10, start_date: Date.today, end_date: nil)
    end_date ||= start_date + 14.days

    # Get candidate events
    candidates = candidate_events(start_date, end_date)
    return [] if candidates.empty?

    # Score each event
    scored = candidates.map do |event|
      score, reasons = calculate_score(event)
      Recommendation.new(event: event, score: score, reasons: reasons)
    end

    # Sort by score and return top results
    scored.sort_by { |r| -r.score }.first(limit)
  end

  # Get specific type recommendations
  def by_type(event_type, limit: 10)
    Event.upcoming
         .where(event_type: event_type)
         .order(starts_at: :asc)
         .limit(limit)
  end

  # Get weekend recommendations
  def weekend(limit: 10)
    next_saturday = Date.today.next_occurring(:saturday)
    next_sunday = next_saturday + 1.day

    Event.in_range(next_saturday, next_sunday.end_of_day)
         .order(starts_at: :asc)
         .limit(limit)
  end

  # Get events happening today
  def today(limit: 10)
    Event.for_day(Date.today)
         .order(starts_at: :asc)
         .limit(limit)
  end

  private

  def candidate_events(start_date, end_date)
    Event.includes(:calendar, post: :creator)
         .in_range(start_date, end_date)
         .where.not(calendar_id: nil)  # Prefer calendar events (scraped/curated)
         .or(Event.in_range(start_date, end_date).joins(:post))
         .distinct
         .limit(100)  # Cap for performance
  end

  def calculate_score(event)
    score = 0.0
    reasons = []

    # Base score for having good data
    if event.description.present?
      score += 5
    end
    if event.venue.present?
      score += 5
    end
    if event.image_url.present?
      score += 3
    end

    # Boost events from subscribed calendars
    if @user && subscribed_calendar_ids.include?(event.calendar_id)
      score += 20
      reasons << "From a calendar you follow"
    end

    # Boost events matching user's preferred event types
    if @user && preferred_event_types.include?(event.event_type)
      score += 15
      reasons << "Matches your interests"
    end

    # Boost events at preferred venues
    if @user && event.venue.present? && preferred_venues.any? { |v| event.venue.downcase.include?(v.downcase) }
      score += 10
      reasons << "At a venue you've visited"
    end

    # Boost events from popular sources
    if event.source_name.present?
      score += 5
      reasons << "Curated from #{event.source_name}"
    end

    # Slight recency boost (events sooner score slightly higher)
    days_away = (event.starts_at.to_date - Date.today).to_i
    if days_away <= 3
      score += 8
      reasons << "Happening soon"
    elsif days_away <= 7
      score += 4
    end

    # Weekend boost
    if event.starts_at.saturday? || event.starts_at.sunday?
      score += 5
      reasons << "Weekend event"
    end

    # Evening boost (popular time)
    hour = event.starts_at.hour
    if hour >= 17 && hour <= 21
      score += 3
    end

    [score, reasons]
  end

  def subscribed_calendar_ids
    @subscribed_calendar_ids ||= @user&.subscribed_calendars&.pluck(:id) || []
  end

  def preferred_event_types
    @preferred_event_types ||= begin
      return [] unless @user

      # Get event types from user's created posts
      types = @user.posts.joins(:event).group("events.event_type").count
      types.sort_by { |_, count| -count }.first(3).map(&:first)
    end
  end

  def preferred_venues
    @preferred_venues ||= begin
      return [] unless @user

      # Get venues from user's created events
      @user.posts.joins(:event)
           .where.not(events: { venue: nil })
           .pluck("events.venue")
           .uniq
           .first(10)
    end
  end
end
