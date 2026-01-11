# RSVP for calendar events
# Tracks user attendance status and optional notes
#
# Statuses:
#   - attending: User plans to attend
#   - maybe: User might attend
#   - declined: User will not attend
#
class EventRsvp < ApplicationRecord
  STATUSES = %w[attending maybe declined].freeze

  belongs_to :event
  belongs_to :user

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :user_id, uniqueness: { scope: :event_id, message: "has already RSVPed to this event" }

  scope :attending, -> { where(status: "attending") }
  scope :maybe, -> { where(status: "maybe") }
  scope :declined, -> { where(status: "declined") }

  def attending?
    status == "attending"
  end

  def maybe?
    status == "maybe"
  end

  def declined?
    status == "declined"
  end
end
