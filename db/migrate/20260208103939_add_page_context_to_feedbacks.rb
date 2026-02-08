class AddPageContextToFeedbacks < ActiveRecord::Migration[7.1]
  def change
    add_column :feedbacks, :email, :string unless column_exists?(:feedbacks, :email)
    add_column :feedbacks, :page_url, :string unless column_exists?(:feedbacks, :page_url)
    add_column :feedbacks, :page_path, :string unless column_exists?(:feedbacks, :page_path)
    add_column :feedbacks, :page_title, :string unless column_exists?(:feedbacks, :page_title)
    add_column :feedbacks, :user_agent, :string unless column_exists?(:feedbacks, :user_agent)
    add_column :feedbacks, :screen_size, :string unless column_exists?(:feedbacks, :screen_size)
    add_column :feedbacks, :viewport_size, :string unless column_exists?(:feedbacks, :viewport_size)
  end
end
