require "rails_helper"

RSpec.describe AccountMap, ".account_type_for_code" do
  describe "balance sheet accounts - Aktiva" do
    it "classifies 0020 (Gewerbliche Schutzrechte) as asset" do
      expect(AccountMap.account_type_for_code("0020")).to eq("asset")
    end

    it "classifies 1000 (Kasse) as asset" do
      expect(AccountMap.account_type_for_code("1000")).to eq("asset")
    end

    it "classifies 1529 (Zurückzuzahlende Vorsteuer) as asset" do
      expect(AccountMap.account_type_for_code("1529")).to eq("asset")
    end
  end

  describe "balance sheet accounts - Passiva (liability)" do
    it "classifies 0750 (Verbindlichkeiten > 5 Jahre) as liability" do
      expect(AccountMap.account_type_for_code("0750")).to eq("liability")
    end

    it "classifies 0950 (Rückstellungen für Pensionen) as liability" do
      expect(AccountMap.account_type_for_code("0950")).to eq("liability")
    end

    it "classifies 1700 (Verbindlichkeiten aus Lieferungen und Leistungen) as liability" do
      expect(AccountMap.account_type_for_code("1700")).to eq("liability")
    end
  end

  describe "balance sheet accounts - Equity" do
    it "classifies 0800 (Gezeichnetes Kapital) as equity" do
      expect(AccountMap.account_type_for_code("0800")).to eq("equity")
    end

    it "classifies 0846 (Gesetzliche Rücklage) as equity" do
      expect(AccountMap.account_type_for_code("0846")).to eq("equity")
    end
  end

  describe "GuV accounts - Expenses" do
    it "classifies 4000 (Material- und Stoffverbrauch) as expense" do
      expect(AccountMap.account_type_for_code("4000")).to eq("expense")
    end

    it "classifies 4100 (Löhne und Gehälter) as expense" do
      expect(AccountMap.account_type_for_code("4100")).to eq("expense")
    end

    it "classifies 2100 (Zinsen und ähnliche Aufwendungen) as expense" do
      expect(AccountMap.account_type_for_code("2100")).to eq("expense")
    end

    it "classifies 2104 (Zinsaufwendungen für Verbindlichkeiten gegenüber Kreditinstituten) as expense" do
      expect(AccountMap.account_type_for_code("2104")).to eq("expense")
    end
  end

  describe "GuV accounts - Revenue" do
    it "classifies 8000 (Umsatzerlöse) as revenue" do
      expect(AccountMap.account_type_for_code("8000")).to eq("revenue")
    end

    it "classifies 2700 (Sonstige betriebliche Erträge) as revenue" do
      expect(AccountMap.account_type_for_code("2700")).to eq("revenue")
    end
  end

  describe "unmapped accounts" do
    it "returns nil for account codes not in any category" do
      # Account 0005 has category "NONE" in the CSV and likely isn't mapped
      result = AccountMap.account_type_for_code("0005")
      expect(result).to be_nil
    end
  end
end
