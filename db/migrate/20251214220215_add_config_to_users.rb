class AddConfigToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :config, :jsonb, default: {}, null: false
  end
end
