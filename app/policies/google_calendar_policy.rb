class GoogleCalendarPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def create?
    user.present?
  end

  def destroy?
    user.present? && record.owned_by?(user)
  end

  def refresh?
    user.present? && record.owned_by?(user)
  end
end
