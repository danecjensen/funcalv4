class Post < ApplicationRecord
  include Likeable, Commentable, Eventable

  belongs_to :creator, class_name: "User", default: -> { Current.user }
  has_rich_text :body

  validates :body, presence: true

  scope :recent, -> { order(created_at: :desc) }
end
