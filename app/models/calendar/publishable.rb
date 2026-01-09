module Calendar::Publishable
  extend ActiveSupport::Concern

  included do
    has_one :publication, class_name: "CalendarPublication", dependent: :destroy

    scope :published, -> { joins(:publication) }
    scope :unpublished, -> { where.missing(:publication) }
  end

  def publish(user: Current.user)
    return true if published?

    create_publication!(user: user)
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def unpublish
    publication&.destroy
  end

  def published?
    publication.present?
  end
end
