class AddPageContextToFeedbacks < ActiveRecord::Migration[7.1]
  def change
    add_column :feedbacks, :page_url, :string
    add_column :feedbacks, :page_title, :string
  end
end
