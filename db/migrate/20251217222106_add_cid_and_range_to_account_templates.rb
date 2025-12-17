class AddCidAndRangeToAccountTemplates < ActiveRecord::Migration[8.1]
  def change
    add_column :account_templates, :cid, :string
    add_column :account_templates, :range, :string
  end
end
