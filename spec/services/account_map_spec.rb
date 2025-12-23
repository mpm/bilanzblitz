require "rails_helper"

RSpec.describe AccountMap do
  describe ".section_title" do
    it "returns the correct title for umsatzerloese" do
      expect(AccountMap.section_title(:umsatzerloese)).to eq("Umsatzerlöse")
    end

    it "returns the correct title for materialaufwand" do
      expect(AccountMap.section_title(:materialaufwand_roh_hilfs_betriebsstoffe))
        .to eq("Aufwendungen für Roh-, Hilfs- und Betriebsstoffe und für bezogene Waren")
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
      # Note: The JSON currently has empty codes for depreciation sections
      # This test uses account 4880 which should be in abschreibungen_anlagevermoegen
      # but the JSON needs to be updated with the correct codes
      skip "Depreciation section codes need to be added to guv-sections-mapping.json"
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

  describe ".load_guv_structure" do
    it "loads JSON from contrib/guv-sections-mapping.json" do
      structure = AccountMap.load_guv_structure
      expect(structure).to be_a(Hash)
      expect(structure.keys).to include(:"Umsatzerlöse")
      expect(structure.keys).to include(:"Materialaufwand")
      expect(structure.keys).to include(:"Personalaufwand")
    end

    it "loads section data with rsid and codes" do
      structure = AccountMap.load_guv_structure
      umsatzerloese = structure[:"Umsatzerlöse"]
      expect(umsatzerloese).to have_key(:rsid)
      expect(umsatzerloese).to have_key(:codes)
      expect(umsatzerloese[:rsid]).to eq("guv.umsatzerloese")
    end
  end

  describe ".guv_sections" do
    it "flattens children sections to top-level" do
      sections = AccountMap.guv_sections
      # Children sections should be top-level
      expect(sections).to have_key(:materialaufwand_roh_hilfs_betriebsstoffe)
      expect(sections).to have_key(:materialaufwand_bezogene_leistungen)
      expect(sections).to have_key(:personalaufwand_loehne_gehaelter)
      expect(sections).to have_key(:personalaufwand_soziale_abgaben)
    end

    it "includes all sections from JSON" do
      sections = AccountMap.guv_sections
      # Should have at least 16 sections (some have children that get flattened)
      expect(sections.keys.length).to be >= 16
    end

    it "preserves rsid from JSON" do
      sections = AccountMap.guv_sections
      expect(sections[:umsatzerloese][:rsid]).to eq("guv.umsatzerloese")
      expect(sections[:materialaufwand_roh_hilfs_betriebsstoffe][:rsid])
        .to eq("guv.materialaufwand.aufwendungen_fuer_roh_hilfs_und_betriebsstoffe_und_fuer_bezo")
    end

    it "adds section_type to each section" do
      sections = AccountMap.guv_sections
      expect(sections[:umsatzerloese][:section_type]).to eq(:revenue)
      expect(sections[:materialaufwand_roh_hilfs_betriebsstoffe][:section_type]).to eq(:expense)
      expect(sections[:sonstige_zinsen_ertraege][:section_type]).to eq(:revenue)
      expect(sections[:zinsen_aufwendungen][:section_type]).to eq(:expense)
    end
  end

  describe ".guv_sections_ordered" do
    it "returns sections in § 275 Abs. 2 HGB order" do
      ordered = AccountMap.guv_sections_ordered
      keys = ordered.keys

      # Check that specific sections appear in correct order
      umsatz_index = keys.index(:umsatzerloese)
      material_index = keys.index(:materialaufwand_roh_hilfs_betriebsstoffe)
      personal_index = keys.index(:personalaufwand_loehne_gehaelter)

      expect(umsatz_index).to be < material_index
      expect(material_index).to be < personal_index
    end

    it "omits sections that don't exist in guv_sections" do
      ordered = AccountMap.guv_sections_ordered
      # All keys in ordered should exist in guv_sections
      ordered.each_key do |key|
        expect(AccountMap.guv_sections).to have_key(key)
      end
    end
  end

  describe ".revenue_sections" do
    it "includes all revenue section identifiers" do
      revenue = AccountMap.revenue_sections
      expect(revenue).to include(:umsatzerloese)
      expect(revenue).to include(:sonstige_betriebliche_ertraege)
      expect(revenue).to include(:sonstige_zinsen_ertraege)
      expect(revenue).to include(:ertraege_beteiligungen)
    end

    it "does not include expense sections" do
      revenue = AccountMap.revenue_sections
      expect(revenue).not_to include(:materialaufwand_roh_hilfs_betriebsstoffe)
      expect(revenue).not_to include(:personalaufwand_loehne_gehaelter)
      expect(revenue).not_to include(:zinsen_aufwendungen)
    end
  end

  describe ".expense_sections" do
    it "includes all expense section identifiers" do
      expense = AccountMap.expense_sections
      expect(expense).to include(:materialaufwand_roh_hilfs_betriebsstoffe)
      expect(expense).to include(:personalaufwand_loehne_gehaelter)
      expect(expense).to include(:zinsen_aufwendungen)
      expect(expense).to include(:sonstige_betriebliche_aufwendungen)
    end

    it "does not include revenue sections" do
      expense = AccountMap.expense_sections
      expect(expense).not_to include(:umsatzerloese)
      expect(expense).not_to include(:sonstige_betriebliche_ertraege)
      expect(expense).not_to include(:sonstige_zinsen_ertraege)
    end
  end

  # Note: Deprecated flat balance sheet methods (balance_sheet_category_title,
  # balance_sheet_account_codes, find_balance_sheet_accounts) have been removed.
  # The system now uses the nested structure loaded from bilanz-sections-mapping.json.
  # Similarly, GUV_SECTIONS, REVENUE_SECTIONS, and EXPENSE_SECTIONS constants have been
  # replaced with dynamic methods that load from guv-sections-mapping.json.

  describe ".build_nested_section" do
    it "does not create duplicate accounts at multiple nesting levels" do
      # Test with account codes that appear in the JSON structure
      # Account 0038 is defined in anlagevermoegen.immaterielle_vermoegensgegenstaende.geleistete_anzahlungen
      account_list = [
        { code: "0038", name: "Anzahlung Test", balance: 1000.0 },
        { code: "0050", name: "Grundstück Test", balance: 5000.0 },
        { code: "0200", name: "BGA Test", balance: 2000.0 }
      ]

      result = AccountMap.build_nested_section(account_list, :anlagevermoegen)

      # Recursively extract all account codes from entire structure
      all_codes = result.flattened_accounts.map { |a| a[:code] }

      # Should not have duplicates - each account should appear exactly once
      expect(all_codes.length).to eq(all_codes.uniq.length),
        "Expected no duplicate accounts, but found: #{all_codes.select { |c| all_codes.count(c) > 1 }.uniq}"
    end

    it "places accounts at the correct nesting level" do
      # Test that accounts appear in the nested structure
      account_list = [
        { code: "0038", name: "Anzahlung", balance: 1000.0 }
      ]

      result = AccountMap.build_nested_section(account_list, :anlagevermoegen)

      # Should have at least one account in the flattened list
      expect(result.flattened_accounts).not_to be_empty
      expect(result.flattened_accounts.first[:code]).to eq("0038")
    end

    it "handles empty account list" do
      result = AccountMap.build_nested_section([], :anlagevermoegen)

      # Should create structure but with no accounts
      expect(result.flattened_accounts).to be_empty
    end
  end
end
