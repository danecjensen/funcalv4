class UserPolicy < ApplicationPolicy
  def show?
    true
  end

  def edit?
    owner_or_admin?
  end

  def update?
    owner_or_admin?
  end

  private

  def owner_or_admin?
    user&.id == record.id || user&.admin?
  end
end
