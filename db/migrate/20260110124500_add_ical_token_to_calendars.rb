class AddIcalTokenToCalendars < ActiveRecord::Migration[7.1]
  def change
    add_column :calendars, :ical_token, :string
    add_index :calendars, :ical_token, unique: true
  end
end
