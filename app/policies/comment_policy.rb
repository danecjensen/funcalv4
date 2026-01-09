class CommentPolicy < ApplicationPolicy
  def create?
    user.present?
  end

  def destroy?
    user&.id == record.creator_id || user&.admin?
  end
end
