class CreateCalendarPublications < ActiveRecord::Migration[7.1]
  def change
    create_table :calendar_publications do |t|
      t.references :calendar, null: false, foreign_key: true, index: { unique: true }
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
