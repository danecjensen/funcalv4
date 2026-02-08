class AddPageContextToFeedbacks < ActiveRecord::Migration[7.1]
  def change
    add_column :feedbacks, :email, :string
    add_column :feedbacks, :page_url, :string
    add_column :feedbacks, :page_path, :string
    add_column :feedbacks, :page_title, :string
    add_column :feedbacks, :user_agent, :string
    add_column :feedbacks, :screen_size, :string
    add_column :feedbacks, :viewport_size, :string
  end
end
