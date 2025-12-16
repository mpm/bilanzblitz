require 'rails_helper'

RSpec.describe GuVService do
  let(:company) { create(:company) }
  let(:fiscal_year) { create(:fiscal_year, company: company, year: 2024) }

  describe '#call' do
    context 'with no parameters' do
      it 'returns failure when company is missing' do
        result = described_class.new(company: nil, fiscal_year: fiscal_year).call

        expect(result.success?).to be false
        expect(result.errors).to include("Company is required")
      end

      it 'returns failure when fiscal year is missing' do
        result = described_class.new(company: company, fiscal_year: nil).call

        expect(result.success?).to be false
        expect(result.errors).to include("Fiscal year is required")
      end
    end

    context 'with valid posted journal entries' do
      before do
        # Create accounts for each GuV section
        @revenue_account = create(:account, company: company, code: "4000", name: "Erlöse", account_type: "revenue")
        @material_account = create(:account, company: company, code: "5000", name: "Materialaufwand", account_type: "expense")
        @personnel_account = create(:account, company: company, code: "6000", name: "Löhne", account_type: "expense")
        @depreciation_account = create(:account, company: company, code: "7600", name: "Abschreibungen", account_type: "expense")
        @other_expense_account = create(:account, company: company, code: "7000", name: "Sonstige Aufwendungen", account_type: "expense")

        # Create a bank account for balancing
        @bank_account = create(:account, company: company, code: "1200", name: "Bank", account_type: "asset")

        # Create journal entry (not posted yet)
        je = create(:journal_entry, company: company, fiscal_year: fiscal_year)

        # Revenue: 10,000 EUR (credit)
        create(:line_item, journal_entry: je, account: @revenue_account, amount: 10000, direction: "credit")

        # Material expense: 3,000 EUR (debit)
        create(:line_item, journal_entry: je, account: @material_account, amount: 3000, direction: "debit")

        # Personnel expense: 2,000 EUR (debit)
        create(:line_item, journal_entry: je, account: @personnel_account, amount: 2000, direction: "debit")

        # Depreciation: 500 EUR (debit)
        create(:line_item, journal_entry: je, account: @depreciation_account, amount: 500, direction: "debit")

        # Other expense: 1,500 EUR (debit)
        create(:line_item, journal_entry: je, account: @other_expense_account, amount: 1500, direction: "debit")

        # Balance with bank (debit 3,000 to balance)
        create(:line_item, journal_entry: je, account: @bank_account, amount: 3000, direction: "debit")

        # Post the journal entry
        je.post!
      end

      it 'calculates GuV structure correctly' do
        result = described_class.new(company: company, fiscal_year: fiscal_year).call

        expect(result.success?).to be true
        expect(result.data).to include(:sections, :net_income, :net_income_label)
      end

      it 'calculates correct net income' do
        result = described_class.new(company: company, fiscal_year: fiscal_year).call

        # Net income = Revenue - Expenses = 10,000 - (3,000 + 2,000 + 500 + 1,500) = 3,000
        expect(result.data[:net_income]).to eq(3000)
      end

      it 'uses correct label for profit' do
        result = described_class.new(company: company, fiscal_year: fiscal_year).call

        expect(result.data[:net_income_label]).to eq("Jahresüberschuss")
      end

      it 'groups accounts into correct sections' do
        result = described_class.new(company: company, fiscal_year: fiscal_year).call

        sections = result.data[:sections]

        # Find each section
        revenue_section = sections.find { |s| s[:key] == :revenue }
        material_section = sections.find { |s| s[:key] == :material_expense }
        personnel_section = sections.find { |s| s[:key] == :personnel_expense }
        depreciation_section = sections.find { |s| s[:key] == :depreciation }
        other_section = sections.find { |s| s[:key] == :other_operating_expense }

        # Verify revenue section
        expect(revenue_section[:label]).to eq("1. Umsatzerlöse")
        expect(revenue_section[:subtotal]).to eq(10000)
        expect(revenue_section[:display_type]).to eq(:positive)
        expect(revenue_section[:accounts].map { |a| a[:account_code] }).to include("4000")

        # Verify material expense section
        expect(material_section[:label]).to eq("2. Materialaufwand")
        expect(material_section[:subtotal]).to eq(-3000)
        expect(material_section[:display_type]).to eq(:negative)
        expect(material_section[:accounts].map { |a| a[:account_code] }).to include("5000")

        # Verify personnel expense section
        expect(personnel_section[:label]).to eq("3. Personalaufwand")
        expect(personnel_section[:subtotal]).to eq(-2000)
        expect(personnel_section[:display_type]).to eq(:negative)

        # Verify depreciation section
        expect(depreciation_section[:label]).to eq("4. Abschreibungen")
        expect(depreciation_section[:subtotal]).to eq(-500)
        expect(depreciation_section[:display_type]).to eq(:negative)

        # Verify other expense section
        expect(other_section[:label]).to eq("5. Sonstige betriebliche Aufwendungen")
        expect(other_section[:subtotal]).to eq(-1500)
        expect(other_section[:display_type]).to eq(:negative)
      end
    end

    context 'with closing entries' do
      before do
        @revenue_account = create(:account, company: company, code: "4000", name: "Erlöse", account_type: "revenue")
        @bank_account = create(:account, company: company, code: "1200", name: "Bank", account_type: "asset")

        # Create normal entry
        je_normal = create(:journal_entry, company: company, fiscal_year: fiscal_year, entry_type: "normal")
        create(:line_item, journal_entry: je_normal, account: @revenue_account, amount: 10000, direction: "credit")
        create(:line_item, journal_entry: je_normal, account: @bank_account, amount: 10000, direction: "debit")
        je_normal.post!

        # Create closing entry (should be excluded)
        je_closing = create(:journal_entry, company: company, fiscal_year: fiscal_year, entry_type: "closing")
        create(:line_item, journal_entry: je_closing, account: @revenue_account, amount: 5000, direction: "debit")
        create(:line_item, journal_entry: je_closing, account: @bank_account, amount: 5000, direction: "credit")
        je_closing.post!
      end

      it 'excludes closing entries from calculation' do
        result = described_class.new(company: company, fiscal_year: fiscal_year).call

        revenue_section = result.data[:sections].find { |s| s[:key] == :revenue }

        # Should only include normal entry (10,000), not closing entry (5,000)
        expect(revenue_section[:subtotal]).to eq(10000)
      end
    end

    context 'with 9xxx closing accounts' do
      before do
        @revenue_account = create(:account, company: company, code: "4000", name: "Erlöse", account_type: "revenue")
        @closing_account = create(:account, company: company, code: "9000", name: "Saldenvorträge", account_type: "equity")

        je = create(:journal_entry, company: company, fiscal_year: fiscal_year)
        create(:line_item, journal_entry: je, account: @revenue_account, amount: 10000, direction: "credit")
        create(:line_item, journal_entry: je, account: @closing_account, amount: 10000, direction: "debit")
        je.post!
      end

      it 'excludes 9xxx accounts from calculation' do
        result = described_class.new(company: company, fiscal_year: fiscal_year).call

        # No section should contain account 9000
        result.data[:sections].each do |section|
          account_codes = section[:accounts].map { |a| a[:account_code] }
          expect(account_codes).not_to include("9000")
        end
      end
    end

    context 'with no posted entries' do
      it 'returns empty GuV structure with zero net income' do
        result = described_class.new(company: company, fiscal_year: fiscal_year).call

        expect(result.success?).to be true
        expect(result.data[:net_income]).to eq(0)
        expect(result.data[:sections]).to all(satisfy { |s| s[:subtotal] == 0 })
      end
    end

    context 'with net loss (negative net income)' do
      before do
        @revenue_account = create(:account, company: company, code: "4000", name: "Erlöse", account_type: "revenue")
        @material_account = create(:account, company: company, code: "5000", name: "Materialaufwand", account_type: "expense")

        je = create(:journal_entry, company: company, fiscal_year: fiscal_year)

        # Revenue: 1,000 EUR
        create(:line_item, journal_entry: je, account: @revenue_account, amount: 1000, direction: "credit")

        # Material expense: 5,000 EUR (more than revenue)
        create(:line_item, journal_entry: je, account: @material_account, amount: 5000, direction: "debit")

        # Balance (credit 4,000 to balance)
        @equity_account = create(:account, company: company, code: "2800", name: "Eigenkapital", account_type: "equity")
        create(:line_item, journal_entry: je, account: @equity_account, amount: 4000, direction: "credit")

        # Post the journal entry
        je.post!
      end

      it 'calculates negative net income correctly' do
        result = described_class.new(company: company, fiscal_year: fiscal_year).call

        # Net income = 1,000 - 5,000 = -4,000 (loss)
        expect(result.data[:net_income]).to eq(-4000)
      end

      it 'uses correct label for loss' do
        result = described_class.new(company: company, fiscal_year: fiscal_year).call

        expect(result.data[:net_income_label]).to eq("Jahresfehlbetrag")
      end
    end
  end
end
