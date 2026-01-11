# Unified service for creating events from all sources:
# - API (Chrome extension)
# - Web UI (calendar form)
# - Scrapers (automated imports)
# - Chat (natural language)
#
# Usage:
#   result = EventCreationService.call(user: current_user, params: event_params, source: :api)
#   if result.success?
#     result.event  # The created event
#     result.post   # The associated post (if created via user source)
#   else
#     result.errors # Array of error messages
#   end
#
class EventCreationService
  Result = Struct.new(:success?, :event, :post, :errors, :duplicate?, keyword_init: true) do
    def success? = self[:success?]
    def duplicate? = self[:duplicate?]
  end

  SOURCES = %i[manual api scraper chat].freeze

  def self.call(**args)
    new(**args).call
  end

  def initialize(user:, params:, source: :manual, skip_deduplication: false)
    @user = user
    @params = params.to_h.with_indifferent_access
    @source = source.to_sym
    @skip_deduplication = skip_deduplication

    validate_source!
  end

  def call
    ActiveRecord::Base.transaction do
      # Check for duplicates (scraped events only by default)
      if should_check_duplicates?
        existing = find_duplicate
        if existing
          return Result.new(
            success?: true,
            event: existing,
            post: existing.post,
            errors: [],
            duplicate?: true
          )
        end
      end

      event = build_event

      if event.save
        Result.new(
          success?: true,
          event: event,
          post: event.post,
          errors: [],
          duplicate?: false
        )
      else
        raise ActiveRecord::Rollback
        Result.new(
          success?: false,
          event: nil,
          post: nil,
          errors: event.errors.full_messages,
          duplicate?: false
        )
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    Result.new(
      success?: false,
      event: nil,
      post: nil,
      errors: e.record.errors.full_messages,
      duplicate?: false
    )
  end

  private

  def validate_source!
    unless SOURCES.include?(@source)
      raise ArgumentError, "Invalid source: #{@source}. Must be one of: #{SOURCES.join(', ')}"
    end
  end

  def should_check_duplicates?
    return false if @skip_deduplication
    @source == :scraper || @params[:source_name].present?
  end

  def find_duplicate
    return nil unless @params[:starts_at].present?

    starts_at = parse_datetime(@params[:starts_at])
    return nil unless starts_at

    # First check by source_id if available
    if @params[:source_name].present? && @params[:source_id].present?
      existing = Event.find_by(
        source_name: @params[:source_name],
        source_id: @params[:source_id]
      )
      return existing if existing
    end

    # Check by title similarity on same day
    Event.for_day(starts_at.to_date).find do |event|
      title_similarity(event.title, @params[:title]) > 0.85
    end
  end

  def build_event
    case @source
    when :scraper
      build_scraped_event
    else
      build_user_event
    end
  end

  def build_user_event
    # Create via Post for social features (likes, comments)
    post = @user.posts.build(body: post_body)
    post.build_event(event_attributes)
    post.save!
    post.event
  end

  def build_scraped_event
    # Direct calendar event for scraped content (no Post)
    calendar = find_or_create_calendar
    calendar.events.build(event_attributes.merge(
      source_name: @params[:source_name],
      source_id: generate_source_id,
      source_url: @params[:source_url]
    ))
  end

  def post_body
    @params[:description].presence ||
      @params[:body].presence ||
      @params[:title].presence ||
      "Event"
  end

  def event_attributes
    {
      title: @params[:title],
      starts_at: parse_datetime(@params[:starts_at]),
      ends_at: parse_datetime(@params[:ends_at]),
      location: @params[:location],
      venue: @params[:venue],
      description: @params[:description],
      all_day: @params[:all_day] || false,
      event_type: @params[:event_type] || "social",
      image_url: @params[:image_url]
    }.compact
  end

  def find_or_create_calendar
    admin = User.find_by(admin: true) || User.first
    raise "No admin user available for scraper calendar" unless admin

    Calendar.find_or_create_by!(
      user: admin,
      name: @params[:source_name] || "Scraped Events"
    ) do |cal|
      cal.description = "Events scraped from #{@params[:source_name]}"
      cal.color = @params[:calendar_color] || "#3788d8"
    end
  end

  def parse_datetime(value)
    return nil if value.blank?
    return value if value.is_a?(Time) || value.is_a?(DateTime)
    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def generate_source_id
    return @params[:source_id] if @params[:source_id].present?

    components = [
      @params[:title].to_s.parameterize,
      parse_datetime(@params[:starts_at])&.to_date&.iso8601
    ].compact.join("-")

    Digest::MD5.hexdigest(components)[0..12]
  end

  def title_similarity(t1, t2)
    return 0.0 if t1.blank? || t2.blank?

    w1 = normalize_title(t1).split.to_set
    w2 = normalize_title(t2).split.to_set

    return 0.0 if (w1 | w2).empty?
    (w1 & w2).size.to_f / (w1 | w2).size
  end

  def normalize_title(text)
    text.to_s.downcase
        .gsub(/[^\w\s]/, "")
        .gsub(/\b(the|a|an|at|in|on|for|and|or|with)\b/, "")
        .squish
  end
end
