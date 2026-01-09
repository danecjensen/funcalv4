class Calendar < ApplicationRecord
  include Subscribable, Publishable

  belongs_to :user
  has_many :events, dependent: :destroy

  validates :name, presence: true
  validates :color, format: { with: /\A#[0-9A-Fa-f]{6}\z/, message: "must be a valid hex color" }, allow_blank: true

  def owned_by?(user)
    return false unless user
    user_id == user.id
  end

  def writable_by?(user)
    owned_by?(user)
  end

  def readable_by?(user)
    return false unless user
    owned_by?(user) || subscribed_by?(user) || published?
  end
end
