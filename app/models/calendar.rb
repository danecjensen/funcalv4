class Calendar < ApplicationRecord
  include Subscribable, Publishable

  belongs_to :user
  has_many :events, dependent: :destroy

  validates :name, presence: true
  validates :color, format: { with: /\A#[0-9A-Fa-f]{6}\z/, message: "must be a valid hex color" }, allow_blank: true
  validates :ical_token, uniqueness: true, allow_nil: true

  before_create :set_ical_token

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

  def regenerate_ical_token!
    update!(ical_token: SecureRandom.urlsafe_base64(32))
  end

  def ical_feed_url
    return nil unless ical_token.present?
    Rails.application.routes.url_helpers.calendar_ical_feed_url(
      ical_token: ical_token,
      format: :ics,
      host: Rails.application.config.action_mailer.default_url_options&.dig(:host) || "localhost:3000"
    )
  end

  private

  def set_ical_token
    self.ical_token ||= SecureRandom.urlsafe_base64(32)
  end
end
