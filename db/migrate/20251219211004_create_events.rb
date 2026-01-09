class CreateEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :events do |t|
      t.references :post, null: false, foreign_key: true, index: { unique: true }
      t.string :title, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at
      t.string :location
      t.boolean :all_day, default: false

      t.timestamps
    end
  end
end
