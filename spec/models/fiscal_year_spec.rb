require 'rails_helper'

RSpec.describe FiscalYear, type: :model do
  describe ".current_for" do
    let(:company) { create(:company) }

    context "when fiscal year exists and is open" do
      let!(:fiscal_year) { create(:fiscal_year, company: company, year: 2024) }

      it "returns the existing fiscal year" do
        result = described_class.current_for(company: company, date: Date.new(2024, 6, 15))
        expect(result).to eq(fiscal_year)
      end

      it "does not create a new fiscal year" do
        expect {
          described_class.current_for(company: company, date: Date.new(2024, 6, 15))
        }.not_to change(FiscalYear, :count)
      end
    end

    context "when fiscal year exists but is closed" do
      let!(:fiscal_year) { create(:fiscal_year, :closed, company: company, year: 2024) }

      it "returns nil" do
        result = described_class.current_for(company: company, date: Date.new(2024, 6, 15))
        expect(result).to be_nil
      end

      it "does not create a new fiscal year" do
        expect {
          described_class.current_for(company: company, date: Date.new(2024, 6, 15))
        }.not_to change(FiscalYear, :count)
      end
    end

    context "when fiscal year does not exist" do
      it "creates a new fiscal year for the given date's year" do
        expect {
          described_class.current_for(company: company, date: Date.new(2025, 6, 15))
        }.to change(FiscalYear, :count).by(1)
      end

      it "returns the newly created fiscal year" do
        result = described_class.current_for(company: company, date: Date.new(2025, 6, 15))
        expect(result).to be_a(FiscalYear)
        expect(result).to be_persisted
        expect(result.year).to eq(2025)
      end

      it "creates the fiscal year with correct attributes" do
        result = described_class.current_for(company: company, date: Date.new(2025, 6, 15))
        expect(result.company).to eq(company)
        expect(result.year).to eq(2025)
        expect(result.start_date).to eq(Date.new(2025, 1, 1))
        expect(result.end_date).to eq(Date.new(2025, 12, 31))
        expect(result.closed).to be false
      end

      it "associates the fiscal year with the company" do
        result = described_class.current_for(company: company, date: Date.new(2025, 6, 15))
        expect(company.fiscal_years).to include(result)
      end
    end

    context "when date is not provided" do
      it "uses the current date" do
        current_year = Date.current.year
        result = described_class.current_for(company: company)
        expect(result.year).to eq(current_year)
      end
    end
  end
end
