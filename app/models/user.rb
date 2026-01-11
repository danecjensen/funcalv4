class User < ApplicationRecord
  include Avatarable

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :omniauthable, :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :posts, foreign_key: :creator_id, dependent: :destroy
  has_many :comments, foreign_key: :creator_id, dependent: :destroy
  has_many :likes, dependent: :destroy
  has_many :services, dependent: :destroy

  # Calendar associations
  has_many :calendars, dependent: :destroy
  has_many :calendar_subscriptions, dependent: :destroy
  has_many :subscribed_calendars, through: :calendar_subscriptions, source: :calendar

  # RSVP associations
  has_many :event_rsvps, dependent: :destroy
  has_many :rsvped_events, through: :event_rsvps, source: :event

  def display_name
    [first_name, last_name].compact.join(" ").presence || email.split("@").first
  end
end
