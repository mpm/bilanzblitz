require 'rails_helper'

RSpec.describe KstService do
  let(:company) { create(:company) }
  let(:fiscal_year) { create(:fiscal_year, company: company, year: 2025, start_date: Date.new(2025, 1, 1), end_date: Date.new(2025, 12, 31)) }

  describe '#call' do
    context 'with valid parameters' do
      let(:service) { described_class.new(company: company, fiscal_year: fiscal_year) }

      before do
        # Mock BalanceSheetService to return GuV data
        balance_sheet_result = double(
          success?: true,
          data: {
            guv: {
              net_income: 50000.00
            }
          }
        )
        allow_any_instance_of(BalanceSheetService).to receive(:call).and_return(balance_sheet_result)
      end

      it 'returns a successful result' do
        result = service.call

        expect(result).to be_a(KstService::Result)
        expect(result.success?).to be true
        expect(result.errors).to be_empty
      end

      it 'includes fiscal year information' do
        result = service.call

        expect(result.data[:fiscal_year_id]).to eq(fiscal_year.id)
        expect(result.data[:year]).to eq(2025)
      end

      it 'includes base data with net income' do
        result = service.call

        expect(result.data[:base_data]).to include(
          net_income: 50000.00,
          net_income_label: "Jahresüberschuss",
          balance_sheet_available: true,
          guv_available: true
        )
      end

      it 'includes all adjustment fields' do
        result = service.call

        expect(result.data[:adjustments]).to include(
          :nicht_abzugsfaehige_aufwendungen,
          :steuerfreie_ertraege,
          :verlustvortrag,
          :spenden,
          :sonderabzuege
        )
      end

      it 'initializes adjustments with zero values' do
        result = service.call

        result.data[:adjustments].each do |_key, adjustment|
          expect(adjustment[:value]).to eq(0.00)
          expect(adjustment[:editable]).to be true
        end
      end

      it 'calculates taxable income without adjustments' do
        result = service.call

        expect(result.data[:calculated][:taxable_income]).to eq(50000.00)
      end

      it 'calculates KSt at 15% rate' do
        result = service.call

        expect(result.data[:calculated][:kst_rate]).to eq(0.15)
        expect(result.data[:calculated][:kst_amount]).to eq(7500.00)
      end

      it 'includes metadata' do
        result = service.call

        expect(result.data[:metadata]).to include(:calculation_date, :stored_balance_sheet)
        expect(result.data[:metadata][:calculation_date]).to eq(Date.today.to_s)
      end
    end

    # context 'with missing company' do
    #   it 'returns a failure result' do
    #     service = described_class.new(company: nil, fiscal_year: fiscal_year)
    #     result = service.call

    #     expect(result.success?).to be false
    #     expect(result.errors).to include("Company is required")
    #   end
    # end

    # context 'with missing fiscal_year' do
    #   it 'returns a failure result' do
    #     service = described_class.new(company: company, fiscal_year: nil)
    #     result = service.call

    #     expect(result.success?).to be false
    #     expect(result.errors).to include("Fiscal year is required")
    #   end
    # end

    context 'with user-provided adjustments' do
      let(:adjustments) do
        {
          nicht_abzugsfaehige_aufwendungen: 2000.00,
          steuerfreie_ertraege: 1000.00,
          verlustvortrag: 10000.00,
          spenden: 500.00,
          sonderabzuege: 300.00
        }
      end
      let(:service) { described_class.new(company: company, fiscal_year: fiscal_year, adjustments: adjustments) }

      before do
        balance_sheet_result = double(
          success?: true,
          data: {
            guv: {
              net_income: 50000.00
            }
          }
        )
        allow_any_instance_of(BalanceSheetService).to receive(:call).and_return(balance_sheet_result)
      end

      it 'applies adjustments to adjustment fields' do
        result = service.call

        expect(result.data[:adjustments][:nicht_abzugsfaehige_aufwendungen][:value]).to eq(2000.00)
        expect(result.data[:adjustments][:steuerfreie_ertraege][:value]).to eq(1000.00)
        expect(result.data[:adjustments][:verlustvortrag][:value]).to eq(10000.00)
      end

      it 'calculates taxable income with adjustments' do
        result = service.call

        # Taxable income = 50000 + 2000 - 1000 - 10000 - 500 - 300 = 40200
        expect(result.data[:calculated][:taxable_income]).to eq(40200.00)
      end

      it 'calculates KSt based on adjusted taxable income' do
        result = service.call

        # KSt = 40200 * 0.15 = 6030
        expect(result.data[:calculated][:kst_amount]).to eq(6030.00)
      end
    end

    context 'with negative net income (loss)' do
      before do
        balance_sheet_result = double(
          success?: true,
          data: {
            guv: {
              net_income: -20000.00
            }
          }
        )
        allow_any_instance_of(BalanceSheetService).to receive(:call).and_return(balance_sheet_result)
      end

      it 'uses "Jahresfehlbetrag" label for losses' do
        service = described_class.new(company: company, fiscal_year: fiscal_year)
        result = service.call

        expect(result.data[:base_data][:net_income_label]).to eq("Jahresfehlbetrag")
      end

      it 'calculates zero KSt for negative taxable income' do
        service = described_class.new(company: company, fiscal_year: fiscal_year)
        result = service.call

        expect(result.data[:calculated][:taxable_income]).to eq(-20000.00)
        expect(result.data[:calculated][:kst_amount]).to eq(0.00)
      end
    end

    context 'with closed fiscal year and stored balance sheet' do
      let!(:balance_sheet) do
        create(:balance_sheet,
          fiscal_year: fiscal_year,
          sheet_type: "closing",
          data: {
            guv: {
              net_income: 60000.00
            }
          }.with_indifferent_access
        )
      end

      before do
        allow(fiscal_year).to receive(:closed?).and_return(true)
      end

      it 'uses stored balance sheet data instead of calculating' do
        service = described_class.new(company: company, fiscal_year: fiscal_year)
        result = service.call

        expect(result.data[:base_data][:net_income]).to eq(60000.00)
        expect(result.data[:metadata][:stored_balance_sheet]).to be true
      end

      it 'does not call BalanceSheetService' do
        expect_any_instance_of(BalanceSheetService).not_to receive(:call)

        service = described_class.new(company: company, fiscal_year: fiscal_year)
        service.call
      end
    end

    context 'when BalanceSheetService fails' do
      before do
        balance_sheet_result = double(
          success?: false,
          data: nil,
          errors: [ "Failed to calculate balance sheet" ]
        )
        allow_any_instance_of(BalanceSheetService).to receive(:call).and_return(balance_sheet_result)
      end

      it 'returns a failure result' do
        service = described_class.new(company: company, fiscal_year: fiscal_year)
        result = service.call

        expect(result.success?).to be false
        expect(result.errors).to include("Failed to calculate balance sheet")
      end
    end

    context 'with on-the-fly GuV generation' do
      before do
        balance_sheet_result = double(
          success?: true,
          data: {
            guv: {
              net_income: 50000.00
            }
          }
        )
        allow_any_instance_of(BalanceSheetService).to receive(:call).and_return(balance_sheet_result)
      end

      it 'marks balance sheet as available but not stored' do
        service = described_class.new(company: company, fiscal_year: fiscal_year)
        result = service.call

        expect(result.data[:base_data][:balance_sheet_available]).to be true
        expect(result.data[:metadata][:stored_balance_sheet]).to be false
      end
    end

    context 'adjustment sign handling' do
      let(:adjustments) do
        {
          nicht_abzugsfaehige_aufwendungen: 1000.00  # Should add to taxable income
        }
      end

      before do
        balance_sheet_result = double(
          success?: true,
          data: {
            guv: {
              net_income: 50000.00
            }
          }
        )
        allow_any_instance_of(BalanceSheetService).to receive(:call).and_return(balance_sheet_result)
      end

      it 'adds non-deductible expenses to taxable income' do
        service = described_class.new(company: company, fiscal_year: fiscal_year, adjustments: adjustments)
        result = service.call

        # 50000 + 1000 = 51000
        expect(result.data[:calculated][:taxable_income]).to eq(51000.00)
      end

      it 'includes adjustment_sign in adjustment data' do
        service = described_class.new(company: company, fiscal_year: fiscal_year, adjustments: adjustments)
        result = service.call

        adjustment = result.data[:adjustments][:nicht_abzugsfaehige_aufwendungen]
        expect(adjustment[:adjustment_sign]).to eq(:add)
      end
    end

    context 'with GuV but no balance sheet' do
      before do
        balance_sheet_result = double(
          success?: true,
          data: {
            guv: {
              net_income: 50000.00
            }
          }
        )
        allow_any_instance_of(BalanceSheetService).to receive(:call).and_return(balance_sheet_result)
      end

      it 'marks GuV as available' do
        service = described_class.new(company: company, fiscal_year: fiscal_year)
        result = service.call

        expect(result.data[:base_data][:guv_available]).to be true
      end
    end

    context 'error handling' do
      it 'returns failure result on StandardError' do
        service = described_class.new(company: company, fiscal_year: fiscal_year)

        # Simulate an error during calculation
        allow_any_instance_of(BalanceSheetService).to receive(:call).and_raise(StandardError, "Unexpected error")

        result = service.call

        expect(result.success?).to be false
        expect(result.errors).to include("Unexpected error")
      end
    end

    context 'rounding' do
      before do
        balance_sheet_result = double(
          success?: true,
          data: {
            guv: {
              net_income: 50123.456  # Unrounded value
            }
          }
        )
        allow_any_instance_of(BalanceSheetService).to receive(:call).and_return(balance_sheet_result)
      end

      it 'rounds all monetary values to 2 decimal places' do
        service = described_class.new(company: company, fiscal_year: fiscal_year)
        result = service.call

        expect(result.data[:base_data][:net_income]).to eq(50123.46)
        expect(result.data[:calculated][:taxable_income]).to eq(50123.46)
        expect(result.data[:calculated][:kst_amount]).to eq(7518.52)
      end
    end
  end
end
