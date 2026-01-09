module Post::Commentable
  extend ActiveSupport::Concern

  included do
    has_many :comments, dependent: :destroy
  end

  def comment(body:, creator: Current.user)
    comments.create!(creator: creator, body: body)
  end

  def comments_count
    comments.size
  end
end
