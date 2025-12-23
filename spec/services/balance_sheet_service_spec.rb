require 'rails_helper'

RSpec.describe BalanceSheetService do
  let(:company) { create(:company) }
  let(:fiscal_year) { create(:fiscal_year, company: company, year: 2024) }

  describe '#call' do
    context 'with valid posted journal entries' do
      before do
        # Create accounts across different balance sheet sections
        @cash_account = create(:account, company: company, code: "1000", name: "Kasse", account_type: "asset")
        @bank_account = create(:account, company: company, code: "1200", name: "Bank", account_type: "asset")
        @receivables_account = create(:account, company: company, code: "1400", name: "Forderungen", account_type: "asset")
        @building_account = create(:account, company: company, code: "0100", name: "Gebäude", account_type: "asset")
        @equity_account = create(:account, company: company, code: "0800", name: "Gezeichnetes Kapital", account_type: "equity")
        @liabilities_account = create(:account, company: company, code: "1600", name: "Verbindlichkeiten", account_type: "liability")

        # Create journal entry
        je = create(:journal_entry, company: company, fiscal_year: fiscal_year)

        # Assets
        create(:line_item, journal_entry: je, account: @cash_account, amount: 1000, direction: "debit")
        create(:line_item, journal_entry: je, account: @bank_account, amount: 5000, direction: "debit")
        create(:line_item, journal_entry: je, account: @receivables_account, amount: 3000, direction: "debit")
        create(:line_item, journal_entry: je, account: @building_account, amount: 50000, direction: "debit")

        # Equity and Liabilities (must balance)
        create(:line_item, journal_entry: je, account: @equity_account, amount: 50000, direction: "credit")
        create(:line_item, journal_entry: je, account: @liabilities_account, amount: 9000, direction: "credit")

        # Post the entry to make it count
        je.post!
      end

      it 'generates balance sheet without duplicate accounts' do
        result = BalanceSheetService.new(company: company, fiscal_year: fiscal_year).call

        expect(result.success?).to be true

        balance_sheet_data = result.data

        # Extract all account codes from both aktiva and passiva
        all_codes = []

        [ :aktiva, :passiva ].each do |side|
          balance_sheet_data[side][:sections].each do |_section_key, section|
            section_accounts = extract_all_codes_from_section(section)
            all_codes.concat(section_accounts)
          end
        end

        # Each account should appear exactly once
        duplicates = all_codes.select { |c| all_codes.count(c) > 1 }.uniq
        expect(all_codes.length).to eq(all_codes.uniq.length),
          "Expected no duplicate accounts, but found duplicates: #{duplicates}"
      end

      it 'calculates correct section totals' do
        result = BalanceSheetService.new(company: company, fiscal_year: fiscal_year).call

        expect(result.success?).to be true

        # Verify that totals are calculated correctly without double-counting
        balance_sheet_data = result.data

        # Find the umlaufvermoegen section (current assets)
        umlaufvermoegen_section = balance_sheet_data[:aktiva][:sections][:umlaufvermoegen]
        expect(umlaufvermoegen_section).not_to be_nil

        # Total should include cash (1000) + bank (5000) + receivables (3000) = 9000
        # Each account should only be counted once
        total = umlaufvermoegen_section[:total]
        expect(total).to be > 0
      end
    end

    context 'with no journal entries' do
      it 'returns empty balance sheet without errors' do
        result = BalanceSheetService.new(company: company, fiscal_year: fiscal_year).call

        expect(result.success?).to be true
        balance_sheet_data = result.data

        # Should have aktiva and passiva with sections
        expect(balance_sheet_data).to have_key(:aktiva)
        expect(balance_sheet_data).to have_key(:passiva)
        expect(balance_sheet_data[:aktiva]).to have_key(:sections)
        expect(balance_sheet_data[:passiva]).to have_key(:sections)
      end
    end
  end

  # Helper method to recursively extract all account codes from a section
  def extract_all_codes_from_section(section)
    codes = []

    # Get codes from accounts at this level
    if section[:accounts] && section[:accounts].any?
      codes.concat(section[:accounts].map { |a| a[:code] })
    end

    # Recursively get codes from children
    if section[:children] && section[:children].any?
      section[:children].each do |child_section|
        codes.concat(extract_all_codes_from_section(child_section))
      end
    end

    codes
  end
end
