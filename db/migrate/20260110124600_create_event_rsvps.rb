class CreateEventRsvps < ActiveRecord::Migration[7.1]
  def change
    create_table :event_rsvps do |t|
      t.references :event, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "attending"
      t.text :note

      t.timestamps
    end

    add_index :event_rsvps, [:event_id, :user_id], unique: true
    add_index :event_rsvps, :status
  end
end
