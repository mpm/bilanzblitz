require "rails_helper"

RSpec.describe AccountMap do
  describe ".section_title" do
    it "returns the correct title for umsatzerloese" do
      expect(AccountMap.section_title(:umsatzerloese)).to eq("1. Umsatzerlöse")
    end

    it "returns the correct title for materialaufwand" do
      expect(AccountMap.section_title(:materialaufwand_roh_hilfs_betriebsstoffe))
        .to eq("5a. Aufwendungen für Roh-, Hilfs- und Betriebsstoffe und für bezogene Waren")
    end

    it "raises an error for unknown section" do
      expect {
        AccountMap.section_title(:unknown_section)
      }.to raise_error(ArgumentError, /Unknown GuV section/)
    end
  end

  describe ".account_codes" do
    it "expands account ranges correctly" do
      codes = AccountMap.account_codes(:umsatzerloese)
      expect(codes).to be_an(Array)
      expect(codes).to include("8000", "8100", "8200") # Sample codes from umsatzerloese range
      expect(codes).to include("2750", "2751", "2752") # Another range
    end

    it "handles sections with multiple ranges" do
      codes = AccountMap.account_codes(:sonstige_betriebliche_aufwendungen)
      expect(codes).to include("4200", "4500", "4930") # Sample codes
      expect(codes).to include("2004", "2090") # Another range
      expect(codes).not_to include("2430", "2440") # Depreciation accounts not included
    end

    it "returns empty array for sections with no configured accounts" do
      codes = AccountMap.account_codes(:bestandsveraenderungen)
      expect(codes).to eq([])
    end

    it "raises an error for unknown section" do
      expect {
        AccountMap.account_codes(:unknown_section)
      }.to raise_error(ArgumentError, /Unknown GuV section/)
    end
  end

  describe ".find_accounts" do
    let(:account_balances) do
      [
        { code: "8000", name: "Revenue 1", balance: 1000.0 },
        { code: "8100", name: "Revenue 2", balance: 2000.0 },
        { code: "3000", name: "Material", balance: 500.0 },
        { code: "4100", name: "Personnel", balance: 300.0 },
        { code: "2430", name: "Depreciation", balance: 100.0 },
        { code: "4500", name: "Other expense", balance: 200.0 }
      ]
    end

    it "filters revenue accounts correctly" do
      result = AccountMap.find_accounts(account_balances, :umsatzerloese)
      expect(result.size).to eq(2)
      expect(result.map { |a| a[:code] }).to contain_exactly("8000", "8100")
    end

    it "filters material accounts correctly" do
      result = AccountMap.find_accounts(account_balances, :materialaufwand_roh_hilfs_betriebsstoffe)
      expect(result.size).to eq(1)
      expect(result.first[:code]).to eq("3000")
    end

    it "filters personnel accounts correctly" do
      result = AccountMap.find_accounts(account_balances, :personalaufwand_loehne_gehaelter)
      expect(result.size).to eq(1)
      expect(result.first[:code]).to eq("4100")
    end

    it "filters depreciation accounts correctly" do
      result = AccountMap.find_accounts(account_balances, :abschreibungen_anlagevermoegen)
      expect(result.size).to eq(1)
      expect(result.first[:code]).to eq("2430")
    end

    it "filters other operating expenses correctly (excludes depreciation range)" do
      result = AccountMap.find_accounts(account_balances, :sonstige_betriebliche_aufwendungen)
      expect(result.size).to eq(1)
      expect(result.first[:code]).to eq("4500")
      expect(result.map { |a| a[:code] }).not_to include("2430") # Depreciation excluded
    end

    it "returns empty array for sections with no matching accounts" do
      result = AccountMap.find_accounts(account_balances, :bestandsveraenderungen)
      expect(result).to eq([])
    end

    it "raises an error for unknown section" do
      expect {
        AccountMap.find_accounts(account_balances, :unknown_section)
      }.to raise_error(ArgumentError, /Unknown GuV section/)
    end
  end

  # Note: Deprecated flat balance sheet methods (balance_sheet_category_title,
  # balance_sheet_account_codes, find_balance_sheet_accounts) have been removed.
  # The system now uses the nested structure loaded from bilanz-sections-mapping.json.
end
