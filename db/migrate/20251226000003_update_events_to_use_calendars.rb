class UpdateEventsToUseCalendars < ActiveRecord::Migration[7.1]
  def change
    # Add calendar_id to events
    add_reference :events, :calendar, null: true, foreign_key: true

    # Make post_id nullable since events will now belong to calendars
    change_column_null :events, :post_id, true

    # Remove the unique index on post_id
    remove_index :events, :post_id, unique: true

    # Add a regular index on post_id for backwards compatibility
    add_index :events, :post_id
  end
end
