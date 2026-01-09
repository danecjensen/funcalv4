class CreateCalendarSubscriptions < ActiveRecord::Migration[7.1]
  def change
    create_table :calendar_subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :calendar, null: false, foreign_key: true

      t.timestamps
    end

    add_index :calendar_subscriptions, [:user_id, :calendar_id], unique: true
  end
end
