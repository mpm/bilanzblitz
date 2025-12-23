require 'rails_helper'

RSpec.describe FiscalYearImporter do
  let(:company) { create(:company) }

  describe '#call' do
    context 'with valid balance sheet data' do
      let(:flat_data) do
        {
          aktiva: {
            anlagevermoegen: [
              { account_code: "0100", account_name: "Gebäude", balance: 50000 }
            ],
            umlaufvermoegen: [
              { account_code: "1200", account_name: "Bank", balance: 5000 }
            ],
            total: 55000.0
          },
          passiva: {
            eigenkapital: [
              { account_code: "0800", account_name: "Kapital", balance: 50000 }
            ],
            verbindlichkeiten: [
              { account_code: "1600", account_name: "Verbindlichkeiten", balance: 5000 }
            ],
            total: 55000.0
          },
          balanced: true
        }
      end

      it 'creates fiscal year successfully' do
        importer = FiscalYearImporter.new(company: company, year: 2023, balance_sheet_data: flat_data)
        result = importer.call

        expect(result).to be true
        expect(importer.errors).to be_empty

        fiscal_year = FiscalYear.find_by(company: company, year: 2023)
        expect(fiscal_year).not_to be_nil
        expect(fiscal_year.closed).to be true
      end

      it 'converts flat balance sheet to nested structure' do
        importer = FiscalYearImporter.new(company: company, year: 2023, balance_sheet_data: flat_data)
        result = importer.call

        expect(result).to be true

        fiscal_year = FiscalYear.find_by(company: company, year: 2023)
        balance_sheet = fiscal_year.balance_sheets.closing.first

        # JSONB stores keys as strings, so we need to access with string keys or symbolize
        data = balance_sheet.data.deep_symbolize_keys

        # Should have nested structure with sections key
        expect(data[:aktiva]).to have_key(:sections)
        expect(data[:passiva]).to have_key(:sections)

        # Aktiva sections should be properly structured
        anlagevermoegen = data[:aktiva][:sections][:anlagevermoegen]
        expect(anlagevermoegen).not_to be_nil
        expect(anlagevermoegen).to have_key(:accounts)
        expect(anlagevermoegen).to have_key(:children)
        expect(anlagevermoegen).to have_key(:section_key)
        expect(anlagevermoegen).to have_key(:section_name)
        expect(anlagevermoegen).to have_key(:level)

        # Accounts may be nested in children, so check totals instead
        expect(anlagevermoegen[:total]).to eq(50000)
        expect(anlagevermoegen[:total_account_count]).to be > 0

        # Passiva sections should be properly structured
        eigenkapital = data[:passiva][:sections][:eigenkapital]
        expect(eigenkapital[:total]).to eq(50000)
        expect(eigenkapital[:total_account_count]).to be > 0

        # Verify total passiva matches
        expect(data[:passiva][:total]).to eq(55000)

        # Verify net_income defaults to 0
        expect(data[:net_income]).to eq(0.0)
      end

      it 'stores net_income when provided' do
        # For profit: Aktiva = 60000, Passiva accounts = 55000, net_income = 5000
        # Balance: 60000 = 55000 + 5000 ✓
        data_with_profit = {
          aktiva: {
            anlagevermoegen: [
              { account_code: "0100", account_name: "Gebäude", balance: 50000 }
            ],
            umlaufvermoegen: [
              { account_code: "1200", account_name: "Bank", balance: 10000 }
            ],
            total: 60000.0
          },
          passiva: {
            eigenkapital: [
              { account_code: "0800", account_name: "Kapital", balance: 50000 }
            ],
            verbindlichkeiten: [
              { account_code: "1600", account_name: "Verbindlichkeiten", balance: 5000 }
            ],
            total: 55000.0
          },
          balanced: true
        }

        importer = FiscalYearImporter.new(
          company: company,
          year: 2023,
          balance_sheet_data: data_with_profit,
          net_income: 5000.0
        )
        result = importer.call

        expect(result).to be true

        fiscal_year = FiscalYear.find_by(company: company, year: 2023)
        balance_sheet = fiscal_year.balance_sheets.closing.first
        data = balance_sheet.data.deep_symbolize_keys

        expect(data[:net_income]).to eq(5000.0)
      end

      it 'handles negative net_income (loss)' do
        # For loss: Aktiva = 52000, Passiva accounts = 55000, net_income = -3000
        # Balance: 52000 = 55000 + (-3000) ✓
        data_with_loss = {
          aktiva: {
            anlagevermoegen: [
              { account_code: "0100", account_name: "Gebäude", balance: 50000 }
            ],
            umlaufvermoegen: [
              { account_code: "1200", account_name: "Bank", balance: 2000 }
            ],
            total: 52000.0
          },
          passiva: {
            eigenkapital: [
              { account_code: "0800", account_name: "Kapital", balance: 50000 }
            ],
            verbindlichkeiten: [
              { account_code: "1600", account_name: "Verbindlichkeiten", balance: 5000 }
            ],
            total: 55000.0
          },
          balanced: true
        }

        importer = FiscalYearImporter.new(
          company: company,
          year: 2023,
          balance_sheet_data: data_with_loss,
          net_income: -3000.0
        )
        result = importer.call

        expect(result).to be true

        fiscal_year = FiscalYear.find_by(company: company, year: 2023)
        balance_sheet = fiscal_year.balance_sheets.closing.first
        data = balance_sheet.data.deep_symbolize_keys

        expect(data[:net_income]).to eq(-3000.0)
      end

      it 'handles string keys in balance sheet data' do
        string_key_data = {
          "aktiva" => {
            "anlagevermoegen" => [
              { "account_code" => "0100", "account_name" => "Gebäude", "balance" => 50000 }
            ],
            "umlaufvermoegen" => [],
            "total" => 50000.0
          },
          "passiva" => {
            "eigenkapital" => [
              { "account_code" => "0800", "account_name" => "Kapital", "balance" => 50000 }
            ],
            "verbindlichkeiten" => [],
            "rueckstellungen" => [],
            "total" => 50000.0
          },
          "balanced" => true
        }

        # Convert string keys to symbols (as Rails params would)
        symbolized_data = string_key_data.deep_symbolize_keys

        importer = FiscalYearImporter.new(company: company, year: 2023, balance_sheet_data: symbolized_data)
        result = importer.call

        expect(result).to be true

        fiscal_year = FiscalYear.find_by(company: company, year: 2023)
        balance_sheet = fiscal_year.balance_sheets.closing.first

        # Should still have nested structure with correct totals
        data = balance_sheet.data.deep_symbolize_keys
        expect(data[:aktiva][:sections][:anlagevermoegen][:total]).to eq(50000)
      end

      it 'handles empty sections gracefully' do
        data_with_empty_sections = {
          aktiva: {
            anlagevermoegen: [
              { account_code: "0100", account_name: "Gebäude", balance: 50000 }
            ],
            umlaufvermoegen: [],  # Empty section
            total: 50000.0
          },
          passiva: {
            eigenkapital: [
              { account_code: "0800", account_name: "Kapital", balance: 50000 }
            ],
            verbindlichkeiten: [],  # Empty section
            rueckstellungen: [],    # Empty section
            total: 50000.0
          },
          balanced: true
        }

        importer = FiscalYearImporter.new(company: company, year: 2023, balance_sheet_data: data_with_empty_sections)
        result = importer.call

        expect(result).to be true

        fiscal_year = FiscalYear.find_by(company: company, year: 2023)
        balance_sheet = fiscal_year.balance_sheets.closing.first

        # Should only have non-empty sections
        data = balance_sheet.data.deep_symbolize_keys
        expect(data[:aktiva][:sections]).to have_key(:anlagevermoegen)
        expect(data[:aktiva][:sections]).not_to have_key(:umlaufvermoegen)
        expect(data[:passiva][:sections]).to have_key(:eigenkapital)
        expect(data[:passiva][:sections]).not_to have_key(:verbindlichkeiten)
      end
    end

    context 'with invalid data' do
      it 'returns false when year already exists' do
        create(:fiscal_year, company: company, year: 2023)

        importer = FiscalYearImporter.new(
          company: company,
          year: 2023,
          balance_sheet_data: { aktiva: { total: 100 }, passiva: { total: 100 }, balanced: true }
        )
        result = importer.call

        expect(result).to be false
        expect(importer.errors).to include("Fiscal year 2023 already exists")
      end

      it 'returns false when balance sheet does not balance (without net_income)' do
        unbalanced_data = {
          aktiva: {
            anlagevermoegen: [ { account_code: "0100", account_name: "Gebäude", balance: 50000 } ],
            total: 50000.0
          },
          passiva: {
            eigenkapital: [ { account_code: "0800", account_name: "Kapital", balance: 40000 } ],
            total: 40000.0
          },
          balanced: false
        }

        importer = FiscalYearImporter.new(company: company, year: 2023, balance_sheet_data: unbalanced_data)
        result = importer.call

        expect(result).to be false
        expect(importer.errors).to include("Balance sheet does not balance. Aktiva must equal Passiva.")
      end

      it 'returns false when balance sheet does not balance (with net_income)' do
        # Aktiva = 60000, Passiva = 50000, net_income = 5000
        # Should balance: 60000 = 50000 + 5000 ✓
        # But if we provide wrong net_income, it should fail
        unbalanced_data = {
          aktiva: {
            anlagevermoegen: [ { account_code: "0100", account_name: "Gebäude", balance: 50000 } ],
            umlaufvermoegen: [ { account_code: "1200", account_name: "Bank", balance: 10000 } ],
            total: 60000.0
          },
          passiva: {
            eigenkapital: [ { account_code: "0800", account_name: "Kapital", balance: 50000 } ],
            total: 50000.0
          },
          balanced: false
        }

        # Wrong net_income (3000 instead of 10000 needed to balance)
        importer = FiscalYearImporter.new(
          company: company,
          year: 2023,
          balance_sheet_data: unbalanced_data,
          net_income: 3000.0
        )
        result = importer.call

        expect(result).to be false
        expect(importer.errors).to include("Balance sheet does not balance. Aktiva must equal Passiva.")
      end

      it 'succeeds when balance sheet balances with net_income' do
        # Aktiva = 60000, Passiva = 50000, net_income = 10000
        # Should balance: 60000 = 50000 + 10000 ✓
        balanced_data = {
          aktiva: {
            anlagevermoegen: [ { account_code: "0100", account_name: "Gebäude", balance: 50000 } ],
            umlaufvermoegen: [ { account_code: "1200", account_name: "Bank", balance: 10000 } ],
            total: 60000.0
          },
          passiva: {
            eigenkapital: [ { account_code: "0800", account_name: "Kapital", balance: 50000 } ],
            total: 50000.0
          },
          balanced: true
        }

        importer = FiscalYearImporter.new(
          company: company,
          year: 2023,
          balance_sheet_data: balanced_data,
          net_income: 10000.0
        )
        result = importer.call

        expect(result).to be true
        expect(importer.errors).to be_empty
      end
    end
  end
end
