class AddPresentationRuleToAccounts < ActiveRecord::Migration[8.1]
  def change
    # Add to account_templates (source of truth from SKR03)
    add_column :account_templates, :presentation_rule, :string

    # Add to accounts (company-specific, inherited from template)
    add_column :accounts, :presentation_rule, :string

    # Index for efficient lookups
    add_index :account_templates, :presentation_rule
  end
end
