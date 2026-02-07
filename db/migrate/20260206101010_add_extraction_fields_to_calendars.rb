class AddExtractionFieldsToCalendars < ActiveRecord::Migration[7.1]
  def change
    add_column :calendars, :extraction_status, :string
    add_column :calendars, :extraction_prompt, :text
  end
end
