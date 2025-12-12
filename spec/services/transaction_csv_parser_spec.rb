require 'rails_helper'

RSpec.describe TransactionCsvParser do
  describe '.parse_german_date' do
    it 'parses German date format DD.MM.YYYY' do
      expect(described_class.parse_german_date('12.06.2024')).to eq(Date.new(2024, 6, 12))
    end

    it 'parses German date format D.M.YYYY' do
      expect(described_class.parse_german_date('1.1.2024')).to eq(Date.new(2024, 1, 1))
    end

    it 'parses German date format DD.MM.YY (2-digit year)' do
      expect(described_class.parse_german_date('1.1.24')).to eq(Date.new(2024, 1, 1))
    end

    it 'parses ISO date format YYYY-MM-DD' do
      expect(described_class.parse_german_date('2024-06-12')).to eq(Date.new(2024, 6, 12))
    end

    it 'returns nil for blank input' do
      expect(described_class.parse_german_date('')).to be_nil
      expect(described_class.parse_german_date(nil)).to be_nil
    end

    it 'returns nil for invalid date strings' do
      expect(described_class.parse_german_date('not a date')).to be_nil
      expect(described_class.parse_german_date('2024/06/12')).to be_nil
    end

    it 'handles whitespace' do
      expect(described_class.parse_german_date('  12.06.2024  ')).to eq(Date.new(2024, 6, 12))
    end
  end

  describe '.parse_german_amount' do
    it 'parses German amount format with euro symbol' do
      expect(described_class.parse_german_amount('1.234,56 €')).to eq(1234.56)
    end

    it 'parses German amount format with EUR text' do
      expect(described_class.parse_german_amount('1.234,56 EUR')).to eq(1234.56)
    end

    it 'parses negative German amounts' do
      expect(described_class.parse_german_amount('-1.234,56 €')).to eq(-1234.56)
    end

    it 'parses amounts without currency symbol' do
      expect(described_class.parse_german_amount('1.234,56')).to eq(1234.56)
    end

    it 'parses simple comma decimal format' do
      expect(described_class.parse_german_amount('1000,00')).to eq(1000.0)
    end

    it 'parses US decimal format (no commas)' do
      expect(described_class.parse_german_amount('1234.56')).to eq(1234.56)
    end

    it 'parses whole amounts with comma (German format)' do
      expect(described_class.parse_german_amount('1.234,00')).to eq(1234.0)
    end

    it 'parses whole amounts without thousands separator' do
      expect(described_class.parse_german_amount('1234')).to eq(1234.0)
    end

    it 'returns nil for blank input' do
      expect(described_class.parse_german_amount('')).to be_nil
      expect(described_class.parse_german_amount(nil)).to be_nil
    end

    it 'handles whitespace' do
      expect(described_class.parse_german_amount('  1.234,56 €  ')).to eq(1234.56)
    end
  end

  describe '#parse' do
    context 'with semicolon-separated CSV (German style)' do
      let(:csv_data) do
        <<~CSV
          Buchungstag;Betrag;Verwendungszweck;Auftraggeber/Empfänger
          12.06.2024;-100,00 €;Supermarket;REWE
          13.06.2024;500,00 €;Salary;Employer GmbH
        CSV
      end

      it 'parses transactions correctly' do
        parser = described_class.new(csv_data)
        results = parser.parse

        expect(results.length).to eq(2)

        expect(results[0].booking_date).to eq(Date.new(2024, 6, 12))
        expect(results[0].amount).to eq(-100.0)
        expect(results[0].remittance_information).to eq('Supermarket')
        expect(results[0].counterparty_name).to eq('REWE')

        expect(results[1].booking_date).to eq(Date.new(2024, 6, 13))
        expect(results[1].amount).to eq(500.0)
        expect(results[1].remittance_information).to eq('Salary')
        expect(results[1].counterparty_name).to eq('Employer GmbH')
      end
    end

    context 'with tab-separated data' do
      let(:csv_data) do
        "Datum\tBetrag\tText\n12.06.2024\t-50,00\tPurchase"
      end

      it 'parses tab-separated data' do
        parser = described_class.new(csv_data)
        results = parser.parse

        expect(results.length).to eq(1)
        expect(results[0].booking_date).to eq(Date.new(2024, 6, 12))
        expect(results[0].amount).to eq(-50.0)
      end
    end

    context 'with comma-separated data' do
      let(:csv_data) do
        <<~CSV
          date,amount,description
          2024-06-12,-100.50,Test payment
        CSV
      end

      it 'parses comma-separated data with ISO dates' do
        parser = described_class.new(csv_data)
        results = parser.parse

        expect(results.length).to eq(1)
        expect(results[0].booking_date).to eq(Date.new(2024, 6, 12))
        expect(results[0].amount).to eq(-100.50)
      end
    end

    context 'without headers' do
      let(:csv_data) do
        "12.06.2024;-100,00 €;Shopping;Store Name"
      end

      it 'auto-detects columns based on content' do
        parser = described_class.new(csv_data)
        results = parser.parse

        expect(results.length).to eq(1)
        expect(results[0].booking_date).to eq(Date.new(2024, 6, 12))
        expect(results[0].amount).to eq(-100.0)
        expect(results[0].remittance_information).to eq('Shopping')
        expect(results[0].counterparty_name).to eq('Store Name')
      end
    end

    context 'with empty input' do
      it 'returns empty array for blank input' do
        expect(described_class.new('').parse).to eq([])
        expect(described_class.new(nil).parse).to eq([])
        expect(described_class.new('   ').parse).to eq([])
      end
    end

    context 'with value date column' do
      let(:csv_data) do
        <<~CSV
          Buchungstag;Valuta;Betrag;Verwendungszweck
          12.06.2024;14.06.2024;-100,00;Payment
        CSV
      end

      it 'parses value date separately from booking date' do
        parser = described_class.new(csv_data)
        results = parser.parse

        expect(results[0].booking_date).to eq(Date.new(2024, 6, 12))
        expect(results[0].value_date).to eq(Date.new(2024, 6, 14))
      end
    end

    context 'with IBAN column' do
      let(:csv_data) do
        <<~CSV
          Datum;Betrag;Name;IBAN
          12.06.2024;-50,00;Company;DE89370400440532013000
        CSV
      end

      it 'parses counterparty IBAN' do
        parser = described_class.new(csv_data)
        results = parser.parse

        expect(results[0].counterparty_name).to eq('Company')
        expect(results[0].counterparty_iban).to eq('DE89370400440532013000')
      end
    end
  end
end
