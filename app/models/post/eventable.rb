module Post::Eventable
  extend ActiveSupport::Concern

  included do
    has_one :event, dependent: :destroy
    accepts_nested_attributes_for :event, reject_if: :all_blank

    scope :with_events, -> { joins(:event) }
  end

  def has_event?
    event.present?
  end
end
