class CreateScraperSources < ActiveRecord::Migration[7.1]
  def change
    create_table :scraper_sources do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :base_url, null: false
      t.string :list_path
      t.string :scraper_class  # For custom scrapers, nil uses DynamicScraper
      t.jsonb :selectors, default: {}
      t.jsonb :schedule, default: {}
      t.string :color, default: "#3788d8"
      t.boolean :enabled, default: true
      t.datetime :last_run_at
      t.datetime :last_success_at
      t.integer :last_run_count, default: 0
      t.integer :total_events_scraped, default: 0
      t.text :last_error

      t.timestamps
    end

    add_index :scraper_sources, :slug, unique: true
    add_index :scraper_sources, :enabled
  end
end
