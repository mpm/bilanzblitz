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
      expect(codes).to include("4000", "4500", "4999")
      expect(codes.first).to eq("4000")
      expect(codes.last).to eq("4999")
      expect(codes.size).to eq(1000) # 4000-4999 = 1000 accounts
    end

    it "handles sections with multiple ranges" do
      codes = AccountMap.account_codes(:sonstige_betriebliche_aufwendungen)
      expect(codes).to include("7000", "7500", "7599") # First range
      expect(codes).to include("7700", "7800", "7999") # Second range
      expect(codes).not_to include("7600", "7650", "7699") # Gap (depreciation)
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
        { code: "4000", name: "Revenue 1", balance: 1000.0 },
        { code: "4500", name: "Revenue 2", balance: 2000.0 },
        { code: "5000", name: "Material", balance: 500.0 },
        { code: "6000", name: "Personnel", balance: 300.0 },
        { code: "7650", name: "Depreciation", balance: 100.0 },
        { code: "7500", name: "Other expense", balance: 200.0 }
      ]
    end

    it "filters revenue accounts correctly" do
      result = AccountMap.find_accounts(account_balances, :umsatzerloese)
      expect(result.size).to eq(2)
      expect(result.map { |a| a[:code] }).to contain_exactly("4000", "4500")
    end

    it "filters material accounts correctly" do
      result = AccountMap.find_accounts(account_balances, :materialaufwand_roh_hilfs_betriebsstoffe)
      expect(result.size).to eq(1)
      expect(result.first[:code]).to eq("5000")
    end

    it "filters depreciation accounts correctly" do
      result = AccountMap.find_accounts(account_balances, :abschreibungen_anlagevermoegen)
      expect(result.size).to eq(1)
      expect(result.first[:code]).to eq("7650")
    end

    it "filters other operating expenses correctly (excludes depreciation range)" do
      result = AccountMap.find_accounts(account_balances, :sonstige_betriebliche_aufwendungen)
      expect(result.size).to eq(1)
      expect(result.first[:code]).to eq("7500")
      expect(result.map { |a| a[:code] }).not_to include("7650") # Depreciation excluded
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

  describe ".balance_sheet_category_title" do
    it "returns the correct title for anlagevermoegen" do
      expect(AccountMap.balance_sheet_category_title(:anlagevermoegen)).to eq("Anlagevermögen")
    end

    it "raises an error for unknown category" do
      expect {
        AccountMap.balance_sheet_category_title(:unknown_category)
      }.to raise_error(ArgumentError, /Unknown balance sheet category/)
    end
  end

  describe ".balance_sheet_account_codes" do
    it "expands account ranges correctly" do
      codes = AccountMap.balance_sheet_account_codes(:anlagevermoegen)
      expect(codes).to include("0000", "0500", "0999")
      expect(codes.size).to eq(1000)
    end

    it "raises an error for unknown category" do
      expect {
        AccountMap.balance_sheet_account_codes(:unknown_category)
      }.to raise_error(ArgumentError, /Unknown balance sheet category/)
    end
  end

  describe ".find_balance_sheet_accounts" do
    let(:account_balances) do
      [
        { code: "0100", name: "Fixed Asset", balance: 10000.0 },
        { code: "1000", name: "Current Asset", balance: 5000.0 },
        { code: "2000", name: "Equity", balance: 8000.0 },
        { code: "3000", name: "Liability", balance: 7000.0 }
      ]
    end

    it "filters fixed assets correctly" do
      result = AccountMap.find_balance_sheet_accounts(account_balances, :anlagevermoegen)
      expect(result.size).to eq(1)
      expect(result.first[:code]).to eq("0100")
    end

    it "filters current assets correctly" do
      result = AccountMap.find_balance_sheet_accounts(account_balances, :umlaufvermoegen)
      expect(result.size).to eq(1)
      expect(result.first[:code]).to eq("1000")
    end

    it "raises an error for unknown category" do
      expect {
        AccountMap.find_balance_sheet_accounts(account_balances, :unknown_category)
      }.to raise_error(ArgumentError, /Unknown balance sheet category/)
    end
  end
end
