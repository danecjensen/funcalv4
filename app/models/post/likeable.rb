module Post::Likeable
  extend ActiveSupport::Concern

  included do
    has_many :likes, dependent: :destroy
  end

  def like(user: Current.user)
    likes.create!(user: user) unless liked_by?(user)
  end

  def unlike(user: Current.user)
    likes.find_by(user: user)&.destroy
  end

  def liked_by?(user)
    return false unless user
    likes.exists?(user: user)
  end

  def likes_count
    likes.size
  end
end
