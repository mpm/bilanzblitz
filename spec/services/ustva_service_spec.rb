require 'rails_helper'

RSpec.describe UstvaService do
  let(:company) { create(:company) }
  let(:fiscal_year) { create(:fiscal_year, company: company, year: 2025, start_date: Date.new(2025, 1, 1), end_date: Date.new(2025, 12, 31)) }
  let(:start_date) { Date.new(2025, 1, 1) }
  let(:end_date) { Date.new(2025, 1, 31) }

  describe '#call' do
    context 'with valid parameters' do
      let(:service) { described_class.new(company: company, start_date: start_date, end_date: end_date) }

      it 'returns a successful result' do
        result = service.call

        expect(result).to be_a(UstvaService::Result)
        expect(result.success?).to be true
        expect(result.errors).to be_empty
      end

      it 'includes period information in the data' do
        result = service.call

        expect(result.data[:period_type]).to eq("monthly")
        expect(result.data[:start_date]).to eq("2025-01-01")
        expect(result.data[:end_date]).to eq("2025-01-31")
      end

      it 'includes metadata' do
        result = service.call

        expect(result.data[:metadata]).to include(:journal_entries_count, :calculation_date)
        expect(result.data[:metadata][:calculation_date]).to eq(Date.today.to_s)
      end
    end

    context 'with missing company' do
      it 'returns a failure result' do
        service = described_class.new(company: nil, start_date: start_date, end_date: end_date)
        result = service.call

        expect(result.success?).to be false
        expect(result.errors).to include("Company is required")
      end
    end

    context 'with missing start_date' do
      it 'returns a failure result' do
        service = described_class.new(company: company, start_date: nil, end_date: end_date)
        result = service.call

        expect(result.success?).to be false
        expect(result.errors).to include("Start date is required")
      end
    end

    context 'with end_date before start_date' do
      it 'returns a failure result' do
        service = described_class.new(company: company, start_date: end_date, end_date: start_date)
        result = service.call

        expect(result.success?).to be false
        expect(result.errors).to include("End date must be after start date")
      end
    end

    context 'with VAT transactions' do
      let!(:bank_account) { create(:account, company: company, code: "1200", name: "Bank", account_type: "asset") }
      let!(:revenue_account) { create(:account, company: company, code: "4000", name: "Revenue", account_type: "revenue") }
      let!(:expense_account) { create(:account, company: company, code: "6000", name: "Expense", account_type: "expense") }
      let!(:vat_output_19_account) { create(:account, company: company, code: Account::VAT_ACCOUNTS[:output_19], name: "USt 19%", account_type: "liability") }
      let!(:vat_input_19_account) { create(:account, company: company, code: Account::VAT_ACCOUNTS[:input_19], name: "Vorsteuer 19%", account_type: "asset") }

      before do
        # Create a posted journal entry with output VAT (revenue transaction)
        je = create(:journal_entry, company: company, fiscal_year: fiscal_year, booking_date: Date.new(2025, 1, 15))
        create(:line_item, journal_entry: je, account: bank_account, amount: 119.00, direction: "debit")
        create(:line_item, journal_entry: je, account: revenue_account, amount: 100.00, direction: "credit")
        create(:line_item, journal_entry: je, account: vat_output_19_account, amount: 19.00, direction: "credit")
        je.update!(posted_at: Time.current)

        # Create a posted journal entry with input VAT (expense transaction)
        je2 = create(:journal_entry, company: company, fiscal_year: fiscal_year, booking_date: Date.new(2025, 1, 20))
        create(:line_item, journal_entry: je2, account: expense_account, amount: 100.00, direction: "debit")
        create(:line_item, journal_entry: je2, account: vat_input_19_account, amount: 19.00, direction: "debit")
        create(:line_item, journal_entry: je2, account: bank_account, amount: 119.00, direction: "credit")
        je2.update!(posted_at: Time.current)
      end

      it 'calculates VAT balances correctly' do
        service = described_class.new(company: company, start_date: start_date, end_date: end_date)
        result = service.call

        expect(result.success?).to be true

        # Find the output VAT field
        output_vat_field = result.data[:fields].find { |f| f[:key] == :kz_81 }
        expect(output_vat_field[:value]).to eq(19.00)

        # Find the input VAT field
        input_vat_field = result.data[:fields].find { |f| f[:key] == :kz_66 }
        expect(input_vat_field[:value]).to eq(19.00)
      end

      it 'calculates net VAT liability correctly' do
        service = described_class.new(company: company, start_date: start_date, end_date: end_date)
        result = service.call

        # Net liability = Output VAT - Input VAT = 19.00 - 19.00 = 0.00
        expect(result.data[:net_vat_liability]).to eq(0.00)
      end

      it 'groups fields by section' do
        service = described_class.new(company: company, start_date: start_date, end_date: end_date)
        result = service.call

        expect(result.data[:sections]).to include(:output_vat, :input_vat, :reverse_charge)
        expect(result.data[:sections][:output_vat]).to include(:label, :fields, :subtotal)
      end

      it 'calculates section subtotals correctly' do
        service = described_class.new(company: company, start_date: start_date, end_date: end_date)
        result = service.call

        expect(result.data[:sections][:output_vat][:subtotal]).to eq(19.00)
        expect(result.data[:sections][:input_vat][:subtotal]).to eq(19.00)
      end

      it 'only includes posted journal entries' do
        # Create an unposted journal entry
        je_unposted = create(:journal_entry, company: company, fiscal_year: fiscal_year, booking_date: Date.new(2025, 1, 25))
        create(:line_item, journal_entry: je_unposted, account: vat_output_19_account, amount: 50.00, direction: "credit")

        service = described_class.new(company: company, start_date: start_date, end_date: end_date)
        result = service.call

        # Output VAT should still be 19.00, not 69.00
        output_vat_field = result.data[:fields].find { |f| f[:key] == :kz_81 }
        expect(output_vat_field[:value]).to eq(19.00)
      end

      it 'only includes transactions within the date range' do
        # Create a posted journal entry outside the date range
        je_outside = create(:journal_entry, company: company, fiscal_year: fiscal_year, booking_date: Date.new(2025, 2, 1))
        create(:line_item, journal_entry: je_outside, account: revenue_account, amount: 50.00, direction: "debit")
        create(:line_item, journal_entry: je_outside, account: vat_output_19_account, amount: 50.00, direction: "credit")
        je_outside.update!(posted_at: Time.current)

        service = described_class.new(company: company, start_date: start_date, end_date: end_date)
        result = service.call

        # Output VAT should still be 19.00, not 69.00
        output_vat_field = result.data[:fields].find { |f| f[:key] == :kz_81 }
        expect(output_vat_field[:value]).to eq(19.00)
      end

      it 'counts journal entries correctly' do
        service = described_class.new(company: company, start_date: start_date, end_date: end_date)
        result = service.call

        expect(result.data[:metadata][:journal_entries_count]).to eq(2)
      end
    end

    context 'period type determination' do
      it 'detects monthly period (28-31 days)' do
        service = described_class.new(company: company, start_date: Date.new(2025, 1, 1), end_date: Date.new(2025, 1, 31))
        result = service.call

        expect(result.data[:period_type]).to eq("monthly")
      end

      it 'detects quarterly period (89-92 days)' do
        service = described_class.new(company: company, start_date: Date.new(2025, 1, 1), end_date: Date.new(2025, 3, 31))
        result = service.call

        expect(result.data[:period_type]).to eq("quarterly")
      end

      it 'detects annual period (365-366 days)' do
        service = described_class.new(company: company, start_date: Date.new(2025, 1, 1), end_date: Date.new(2025, 12, 31))
        result = service.call

        expect(result.data[:period_type]).to eq("annual")
      end

      it 'returns custom for non-standard periods' do
        service = described_class.new(company: company, start_date: Date.new(2025, 1, 1), end_date: Date.new(2025, 1, 15))
        result = service.call

        expect(result.data[:period_type]).to eq("custom")
      end
    end

    context 'with positive net VAT liability' do
      let!(:revenue_account) { create(:account, company: company, code: "4000", name: "Revenue", account_type: "revenue") }
      let!(:vat_output_19_account) { create(:account, company: company, code: Account::VAT_ACCOUNTS[:output_19], name: "USt 19%", account_type: "liability") }

      before do
        je = create(:journal_entry, company: company, fiscal_year: fiscal_year, booking_date: Date.new(2025, 1, 15))
        create(:line_item, journal_entry: je, account: revenue_account, amount: 100.00, direction: "debit")
        create(:line_item, journal_entry: je, account: vat_output_19_account, amount: 100.00, direction: "credit")
        je.update!(posted_at: Time.current)
      end

      it 'calculates positive net VAT liability (amount owed)' do
        service = described_class.new(company: company, start_date: start_date, end_date: end_date)
        result = service.call

        expect(result.data[:net_vat_liability]).to eq(100.00)
      end
    end

    context 'with negative net VAT liability' do
      let!(:expense_account) { create(:account, company: company, code: "6000", name: "Expense", account_type: "expense") }
      let!(:vat_input_19_account) { create(:account, company: company, code: Account::VAT_ACCOUNTS[:input_19], name: "Vorsteuer 19%", account_type: "asset") }

      before do
        je = create(:journal_entry, company: company, fiscal_year: fiscal_year, booking_date: Date.new(2025, 1, 15))
        create(:line_item, journal_entry: je, account: vat_input_19_account, amount: 100.00, direction: "debit")
        create(:line_item, journal_entry: je, account: expense_account, amount: 100.00, direction: "credit")
        je.update!(posted_at: Time.current)
      end

      it 'calculates negative net VAT liability (refund)' do
        service = described_class.new(company: company, start_date: start_date, end_date: end_date)
        result = service.call

        expect(result.data[:net_vat_liability]).to eq(-100.00)
      end
    end

    context 'error handling' do
      it 'returns failure result on StandardError' do
        service = described_class.new(company: company, start_date: start_date, end_date: end_date)

        # Simulate an error during calculation
        allow(service).to receive(:calculate_vat_balances).and_raise(StandardError, "Database error")

        result = service.call

        expect(result.success?).to be false
        expect(result.errors).to include("Database error")
      end
    end
  end
end
