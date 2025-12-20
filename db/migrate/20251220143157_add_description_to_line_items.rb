class AddDescriptionToLineItems < ActiveRecord::Migration[8.1]
  def change
    add_column :line_items, :description, :text
  end
end
