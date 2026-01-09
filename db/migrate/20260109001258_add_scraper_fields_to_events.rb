class AddScraperFieldsToEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :events, :source_url, :string
    add_column :events, :image_url, :string
    add_column :events, :venue, :string
    add_column :events, :description, :text
    add_column :events, :source_name, :string
    add_column :events, :source_id, :string

    add_index :events, [:source_name, :source_id], unique: true, where: "source_name IS NOT NULL AND source_id IS NOT NULL"
  end
end
