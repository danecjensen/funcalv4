class CalendarPublication < ApplicationRecord
  belongs_to :calendar, touch: true
  belongs_to :user
end
