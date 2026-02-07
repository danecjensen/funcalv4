class CreateFeedbacks < ActiveRecord::Migration[7.1]
  def change
    create_table :feedbacks do |t|
      t.text :feedback_text, null: false
      t.string :submitted_by
      t.string :status, default: "pending", null: false
      t.text :agent_log
      t.string :commit_sha
      t.string :checkpoint_id
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end
  end
end
