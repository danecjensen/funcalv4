class Event < ApplicationRecord
  EVENT_TYPES = %w[social meeting workshop community celebration].freeze

  belongs_to :post, optional: true
  belongs_to :calendar, optional: true
  has_one :creator, through: :post
  has_many :rsvps, class_name: "EventRsvp", dependent: :destroy
  has_many :attendees, through: :rsvps, source: :user

  validates :title, :starts_at, presence: true
  validates :event_type, inclusion: { in: EVENT_TYPES }
  validate :must_belong_to_calendar_or_post

  # Get the owner of the event (via calendar or post)
  def owner
    calendar&.user || creator
  end

  # RSVP helpers
  def rsvp_for(user)
    return nil unless user
    rsvps.find_by(user: user)
  end

  def rsvped_by?(user)
    rsvp_for(user).present?
  end

  def attending_count
    rsvps.attending.count
  end

  def maybe_count
    rsvps.maybe.count
  end

  # PostgreSQL range-based scopes (uses GiST index)
  # Finds events that overlap with the given time range
  scope :overlapping, ->(range) {
    where("occurs_at && tstzrange(?, ?)", range.begin, range.end)
  }

  # Events happening right now
  scope :happening_now, -> {
    where("occurs_at @> ?::timestamptz", Time.current)
  }

  # Legacy scopes using starts_at (kept for compatibility)
  scope :upcoming, -> { where("starts_at >= ?", Time.current) }
  scope :in_range, ->(start_date, end_date) { where(starts_at: start_date..end_date) }
  scope :for_day, ->(date) { where("DATE(starts_at) = ?", date) }

  # Sync occurs_at when starts_at or ends_at changes
  before_save :sync_occurs_at, if: -> { starts_at_changed? || ends_at_changed? }

  private

  def sync_occurs_at
    return unless starts_at.present?

    end_time = ends_at.presence || starts_at + 1.hour
    self.occurs_at = starts_at...end_time
  end

  def must_belong_to_calendar_or_post
    # Check for both id and association to support nested attributes
    has_calendar = calendar_id.present? || calendar.present?
    has_post = post_id.present? || post.present?
    unless has_calendar || has_post
      errors.add(:base, "Event must belong to either a calendar or a post")
    end
  end
end
