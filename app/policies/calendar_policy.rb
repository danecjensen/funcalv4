class CalendarPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    # Can view if: owner, subscribed, or calendar is public
    record.readable_by?(user)
  end

  def create?
    user.present?
  end

  def update?
    owner_or_admin?
  end

  def destroy?
    owner_or_admin?
  end

  def subscribe?
    # Can subscribe if: not the owner and calendar exists
    user.present? && user.id != record.user_id
  end

  def unsubscribe?
    # Can unsubscribe if: currently subscribed
    user.present? && record.subscribed_by?(user)
  end

  class Scope < Scope
    def resolve
      # Show calendars that are: owned by user, subscribed to, or published
      if user
        scope.left_joins(:calendar_subscriptions, :publication)
             .where("calendars.user_id = ? OR calendar_publications.id IS NOT NULL OR calendar_subscriptions.user_id = ?",
                    user.id, user.id)
             .distinct
      else
        scope.published
      end
    end
  end

  private

  def owner_or_admin?
    user&.id == record.user_id || user&.admin?
  end
end
