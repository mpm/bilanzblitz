# frozen_string_literal: true

require "rails_helper"

RSpec.describe BalanceSheetSection do
  let(:accounts) do
    [
      { code: "0100", name: "Account 1", balance: 1000.0 },
      { code: "0200", name: "Account 2", balance: 2000.0 }
    ]
  end

  let(:section) do
    described_class.new(
      section_key: :anlagevermoegen,
      section_name: "Anlagevermögen",
      level: 1,
      accounts: accounts
    )
  end

  describe "#initialize" do
    it "creates section with correct attributes" do
      expect(section.section_key).to eq(:anlagevermoegen)
      expect(section.section_name).to eq("Anlagevermögen")
      expect(section.level).to eq(1)
      expect(section.accounts).to eq(accounts)
      expect(section.children).to be_empty
    end

    it "defaults to empty accounts array" do
      section_without_accounts = described_class.new(
        section_key: :test,
        section_name: "Test",
        level: 1
      )
      expect(section_without_accounts.accounts).to eq([])
    end

    it "defaults to level 1" do
      section_default_level = described_class.new(
        section_key: :test,
        section_name: "Test"
      )
      expect(section_default_level.level).to eq(1)
    end
  end

  describe "#add_child" do
    let(:child_section) do
      described_class.new(
        section_key: :immaterielle_vermogensgegenstaende,
        section_name: "Immaterielle Vermögensgegenstände",
        level: 2,
        accounts: [ { code: "0300", name: "Child Account", balance: 500.0 } ]
      )
    end

    it "adds child section" do
      section.add_child(child_section)
      expect(section.children).to include(child_section)
    end

    it "maintains multiple children" do
      child2 = described_class.new(
        section_key: :sachanlagen,
        section_name: "Sachanlagen",
        level: 2,
        accounts: []
      )
      section.add_child(child_section)
      section.add_child(child2)
      expect(section.children).to contain_exactly(child_section, child2)
    end

    it "returns self for chaining" do
      result = section.add_child(child_section)
      expect(result).to eq(section)
    end
  end

  describe "#own_accounts" do
    it "returns accounts at this level only" do
      expect(section.own_accounts).to eq(accounts)
    end
  end

  describe "#flattened_accounts" do
    it "returns own accounts when no children" do
      expect(section.flattened_accounts).to eq(accounts)
    end

    it "includes accounts from all children recursively" do
      child_accounts = [ { code: "0300", name: "Child Account", balance: 500.0 } ]
      child_section = described_class.new(
        section_key: :immaterielle_vermogensgegenstaende,
        section_name: "Immaterielle Vermögensgegenstände",
        level: 2,
        accounts: child_accounts
      )

      grandchild_accounts = [ { code: "0400", name: "Grandchild Account", balance: 250.0 } ]
      grandchild_section = described_class.new(
        section_key: :selbst_geschaffene_schutzrechte,
        section_name: "Selbst geschaffene Schutzrechte",
        level: 3,
        accounts: grandchild_accounts
      )

      child_section.add_child(grandchild_section)
      section.add_child(child_section)

      flattened = section.flattened_accounts
      expect(flattened).to include(*accounts)
      expect(flattened).to include(*child_accounts)
      expect(flattened).to include(*grandchild_accounts)
      expect(flattened.size).to eq(4)
    end

    it "handles deeply nested structure (3+ levels)" do
      level2 = described_class.new(section_key: :level2, section_name: "Level 2", level: 2, accounts: [ { code: "L2", name: "L2", balance: 100.0 } ])
      level3 = described_class.new(section_key: :level3, section_name: "Level 3", level: 3, accounts: [ { code: "L3", name: "L3", balance: 50.0 } ])
      level4 = described_class.new(section_key: :level4, section_name: "Level 4", level: 4, accounts: [ { code: "L4", name: "L4", balance: 25.0 } ])

      level3.add_child(level4)
      level2.add_child(level3)
      section.add_child(level2)

      expect(section.flattened_accounts.size).to eq(5)
      expect(section.flattened_accounts.map { |a| a[:code] }).to contain_exactly("0100", "0200", "L2", "L3", "L4")
    end
  end

  describe "#own_total" do
    it "calculates sum of own accounts only" do
      expect(section.own_total).to eq(3000.0)
    end

    it "returns 0 for empty section" do
      empty_section = described_class.new(
        section_key: :test,
        section_name: "Test",
        level: 1,
        accounts: []
      )
      expect(empty_section.own_total).to eq(0.0)
    end
  end

  describe "#total" do
    it "equals own_total when no children" do
      expect(section.total).to eq(section.own_total)
      expect(section.total).to eq(3000.0)
    end

    it "includes totals from all children" do
      child_section = described_class.new(
        section_key: :child,
        section_name: "Child",
        level: 2,
        accounts: [ { code: "0300", name: "Child", balance: 500.0 } ]
      )

      grandchild_section = described_class.new(
        section_key: :grandchild,
        section_name: "Grandchild",
        level: 3,
        accounts: [ { code: "0400", name: "Grandchild", balance: 250.0 } ]
      )

      child_section.add_child(grandchild_section)
      section.add_child(child_section)

      # 3000 (own) + 500 (child) + 250 (grandchild) = 3750
      expect(section.total).to eq(3750.0)
    end

    it "handles empty sections" do
      empty_section = described_class.new(
        section_key: :test,
        section_name: "Test",
        level: 1,
        accounts: []
      )
      expect(empty_section.total).to eq(0.0)
    end

    it "handles multiple children" do
      child1 = described_class.new(
        section_key: :child1,
        section_name: "Child 1",
        level: 2,
        accounts: [ { code: "C1", name: "C1", balance: 100.0 } ]
      )
      child2 = described_class.new(
        section_key: :child2,
        section_name: "Child 2",
        level: 2,
        accounts: [ { code: "C2", name: "C2", balance: 200.0 } ]
      )

      section.add_child(child1)
      section.add_child(child2)

      # 3000 + 100 + 200 = 3300
      expect(section.total).to eq(3300.0)
    end
  end

  describe "#empty?" do
    it "returns false when section has accounts" do
      expect(section.empty?).to be false
    end

    it "returns true when section has no accounts and no children" do
      empty_section = described_class.new(
        section_key: :test,
        section_name: "Test",
        level: 1,
        accounts: []
      )
      expect(empty_section.empty?).to be true
    end

    it "returns false when section has no accounts but has non-empty children" do
      parent = described_class.new(
        section_key: :parent,
        section_name: "Parent",
        level: 1,
        accounts: []
      )
      child = described_class.new(
        section_key: :child,
        section_name: "Child",
        level: 2,
        accounts: [ { code: "C1", name: "C1", balance: 100.0 } ]
      )
      parent.add_child(child)

      expect(parent.empty?).to be false
    end

    it "returns true when section and all children are empty" do
      parent = described_class.new(
        section_key: :parent,
        section_name: "Parent",
        level: 1,
        accounts: []
      )
      child = described_class.new(
        section_key: :child,
        section_name: "Child",
        level: 2,
        accounts: []
      )
      parent.add_child(child)

      expect(parent.empty?).to be true
    end
  end

  describe "#account_count" do
    it "returns number of accounts at this level only" do
      expect(section.account_count).to eq(2)
    end

    it "returns 0 for empty section" do
      empty_section = described_class.new(
        section_key: :test,
        section_name: "Test",
        level: 1,
        accounts: []
      )
      expect(empty_section.account_count).to eq(0)
    end
  end

  describe "#total_account_count" do
    it "equals account_count when no children" do
      expect(section.total_account_count).to eq(section.account_count)
      expect(section.total_account_count).to eq(2)
    end

    it "includes count from all children" do
      child = described_class.new(
        section_key: :child,
        section_name: "Child",
        level: 2,
        accounts: [ { code: "C1", name: "C1", balance: 100.0 } ]
      )
      grandchild = described_class.new(
        section_key: :grandchild,
        section_name: "Grandchild",
        level: 3,
        accounts: [
          { code: "G1", name: "G1", balance: 50.0 },
          { code: "G2", name: "G2", balance: 75.0 }
        ]
      )

      child.add_child(grandchild)
      section.add_child(child)

      # 2 (own) + 1 (child) + 2 (grandchild) = 5
      expect(section.total_account_count).to eq(5)
    end
  end

  describe "#to_h" do
    it "converts to hash representation" do
      hash = section.to_h
      expect(hash[:section_key]).to eq(:anlagevermoegen)
      expect(hash[:section_name]).to eq("Anlagevermögen")
      expect(hash[:level]).to eq(1)
      expect(hash[:accounts]).to eq(accounts)
      expect(hash[:own_total]).to eq(3000.0)
      expect(hash[:total]).to eq(3000.0)
      expect(hash[:account_count]).to eq(2)
      expect(hash[:total_account_count]).to eq(2)
    end

    it "includes children when requested" do
      child = described_class.new(
        section_key: :child,
        section_name: "Child",
        level: 2,
        accounts: [ { code: "C1", name: "C1", balance: 100.0 } ]
      )
      section.add_child(child)

      hash = section.to_h(include_children: true)
      expect(hash[:children]).to be_present
      expect(hash[:children].size).to eq(1)
      expect(hash[:children].first[:section_key]).to eq(:child)
    end

    it "excludes children when requested" do
      child = described_class.new(
        section_key: :child,
        section_name: "Child",
        level: 2,
        accounts: [ { code: "C1", name: "C1", balance: 100.0 } ]
      )
      section.add_child(child)

      hash = section.to_h(include_children: false)
      expect(hash[:children]).to be_nil
    end

    it "rounds totals to 2 decimal places" do
      section_with_decimals = described_class.new(
        section_key: :test,
        section_name: "Test",
        level: 1,
        accounts: [ { code: "T1", name: "T1", balance: 100.333333 } ]
      )
      hash = section_with_decimals.to_h
      expect(hash[:own_total]).to eq(100.33)
      expect(hash[:total]).to eq(100.33)
    end
  end

  describe "#find_child" do
    let(:child1) do
      described_class.new(
        section_key: :child1,
        section_name: "Child 1",
        level: 2,
        accounts: []
      )
    end

    let(:child2) do
      described_class.new(
        section_key: :child2,
        section_name: "Child 2",
        level: 2,
        accounts: []
      )
    end

    before do
      section.add_child(child1)
      section.add_child(child2)
    end

    it "finds child by key" do
      found = section.find_child(:child1)
      expect(found).to eq(child1)
    end

    it "returns nil when child not found" do
      found = section.find_child(:nonexistent)
      expect(found).to be_nil
    end

    it "only searches direct children (non-recursive)" do
      grandchild = described_class.new(
        section_key: :grandchild,
        section_name: "Grandchild",
        level: 3,
        accounts: []
      )
      child1.add_child(grandchild)

      found = section.find_child(:grandchild)
      expect(found).to be_nil
    end
  end

  describe "#find_section" do
    let(:child) do
      described_class.new(
        section_key: :child,
        section_name: "Child",
        level: 2,
        accounts: []
      )
    end

    let(:grandchild) do
      described_class.new(
        section_key: :grandchild,
        section_name: "Grandchild",
        level: 3,
        accounts: []
      )
    end

    before do
      child.add_child(grandchild)
      section.add_child(child)
    end

    it "finds self by key" do
      found = section.find_section(:anlagevermoegen)
      expect(found).to eq(section)
    end

    it "finds child by key" do
      found = section.find_section(:child)
      expect(found).to eq(child)
    end

    it "finds deeply nested section" do
      found = section.find_section(:grandchild)
      expect(found).to eq(grandchild)
    end

    it "returns nil when not found" do
      found = section.find_section(:nonexistent)
      expect(found).to be_nil
    end

    it "performs depth-first search" do
      # Add multiple children to test search order
      another_child = described_class.new(
        section_key: :another_child,
        section_name: "Another Child",
        level: 2,
        accounts: []
      )
      section.add_child(another_child)

      found = section.find_section(:grandchild)
      expect(found).to eq(grandchild)
    end
  end
end
