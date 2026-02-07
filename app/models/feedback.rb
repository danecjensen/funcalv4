class Feedback < ApplicationRecord
  validates :feedback_text, presence: true

  scope :pending, -> { where(status: "pending") }
  scope :running, -> { where(status: "running") }
  scope :success, -> { where(status: "success") }
  scope :failed, -> { where(status: "failed") }
  scope :reverted, -> { where(status: "reverted") }
  scope :recent, -> { order(created_at: :desc) }
end
