class EventPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    # Can view event if can view the calendar (or it's a post event)
    return true if record.post_id.present?
    return false unless record.calendar

    record.calendar.readable_by?(user)
  end

  def create?
    # Can create event if can write to the calendar
    return false unless user.present?
    return true if creating_post_event?

    # For calendar events, need write access
    calendar = record.calendar || Calendar.find_by(id: record.calendar_id)
    calendar&.writable_by?(user)
  end

  def update?
    # Can update if: own the calendar, own the post, or admin
    return owner_of_post_or_admin? if record.post_id.present?
    return owner_of_calendar_or_admin?
  end

  def destroy?
    # Same as update
    return owner_of_post_or_admin? if record.post_id.present?
    return owner_of_calendar_or_admin?
  end

  class Scope < Scope
    def resolve
      # Show events from: owned calendars, subscribed calendars, published calendars, or posts
      if user
        scope.left_joins(calendar: [:calendar_subscriptions, :publication])
             .left_joins(:post)
             .where("calendars.user_id = ? OR calendar_publications.id IS NOT NULL OR calendar_subscriptions.user_id = ? OR events.post_id IS NOT NULL",
                    user.id, user.id)
             .distinct
      else
        scope.left_joins(calendar: :publication)
             .where("calendar_publications.id IS NOT NULL OR events.post_id IS NOT NULL")
             .distinct
      end
    end
  end

  private

  def creating_post_event?
    record.post_id.present?
  end

  def owner_of_calendar_or_admin?
    return false unless record.calendar
    user&.id == record.calendar.user_id || user&.admin?
  end

  def owner_of_post_or_admin?
    return false unless record.post
    user&.id == record.post.creator_id || user&.admin?
  end
end
