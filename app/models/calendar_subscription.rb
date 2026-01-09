class CalendarSubscription < ApplicationRecord
  belongs_to :user
  belongs_to :calendar, touch: true

  validates :user_id, uniqueness: { scope: :calendar_id }
  validate :cannot_subscribe_to_own_calendar

  private

  def cannot_subscribe_to_own_calendar
    errors.add(:base, "Cannot subscribe to your own calendar") if user_id == calendar&.user_id
  end
end
