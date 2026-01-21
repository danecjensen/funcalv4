class AddCalendarIdToScraperSources < ActiveRecord::Migration[7.1]
  def change
    add_reference :scraper_sources, :calendar, null: true, foreign_key: true
    add_index :scraper_sources, [:calendar_id, :slug], unique: true, where: "calendar_id IS NOT NULL"
  end
end
