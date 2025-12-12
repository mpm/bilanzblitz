class AddConfigToBankTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :bank_transactions, :config, :jsonb, default: {}
  end
end
