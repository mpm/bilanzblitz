require 'rails_helper'

RSpec.describe Company, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      company = build(:company)
      expect(company).to be_valid
    end

    it "requires a name" do
      company = build(:company, name: nil)
      expect(company).not_to be_valid
    end
  end

  describe "associations" do
    it { should have_many(:company_memberships).dependent(:destroy) }
    it { should have_many(:users).through(:company_memberships) }
    it { should have_many(:fiscal_years).dependent(:destroy) }
    it { should have_many(:accounts).dependent(:destroy) }
    it { should have_many(:bank_accounts).dependent(:destroy) }
    it { should have_many(:documents).dependent(:destroy) }
    it { should have_many(:journal_entries).dependent(:destroy) }
    it { should have_many(:tax_reports).dependent(:destroy) }
  end
end
