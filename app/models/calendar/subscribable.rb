module Calendar::Subscribable
  extend ActiveSupport::Concern

  included do
    has_many :calendar_subscriptions, dependent: :destroy
    has_many :subscribers, through: :calendar_subscriptions, source: :user

    scope :subscribed_by, ->(user) {
      joins(:calendar_subscriptions).where(calendar_subscriptions: { user_id: user.id })
    }
  end

  def subscribe(user)
    return false if owned_by?(user)
    return true if subscribed_by?(user)

    calendar_subscriptions.create!(user: user)
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def unsubscribe(user)
    calendar_subscriptions.where(user: user).destroy_all
  end

  def subscribed_by?(user)
    return false unless user
    subscribers.exists?(user.id)
  end
end
