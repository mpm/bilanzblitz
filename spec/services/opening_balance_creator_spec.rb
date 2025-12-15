# frozen_string_literal: true

require "rails_helper"

RSpec.describe OpeningBalanceCreator, type: :service do
  let(:chart_of_accounts) do
    ChartOfAccounts.find_or_create_by!(name: "SKR03", country_code: "DE") do |chart|
      chart.description = "Standard Kontenrahmen 03"
    end
  end

  let(:company) { create(:company, chart_of_accounts: chart_of_accounts) }
  let(:fiscal_year_2021) { create(:fiscal_year, company: company, year: 2021, start_date: Date.new(2021, 1, 1), end_date: Date.new(2021, 12, 31)) }

  # Create required account templates
  before do
    # EBK account (9000)
    chart_of_accounts.account_templates.find_or_create_by!(code: "9000") do |template|
      template.name = "Saldenvorträge, Sachkonten"
      template.account_type = "equity"
      template.is_system_account = true
    end

    # Asset accounts
    chart_of_accounts.account_templates.find_or_create_by!(code: "1529") do |template|
      template.name = "Rückforderungen USt"
      template.account_type = "asset"
    end

    chart_of_accounts.account_templates.find_or_create_by!(code: "1200") do |template|
      template.name = "Bank"
      template.account_type = "asset"
    end

    # Equity accounts
    chart_of_accounts.account_templates.find_or_create_by!(code: "0800") do |template|
      template.name = "Gezeichnetes Kapital"
      template.account_type = "equity"
    end

    chart_of_accounts.account_templates.find_or_create_by!(code: "0868") do |template|
      template.name = "Verlustvortrag"
      template.account_type = "equity"
    end

    chart_of_accounts.account_templates.find_or_create_by!(code: "9805") do |template|
      template.name = "Fehlbetrag"
      template.account_type = "equity"
    end

    # Liability account
    chart_of_accounts.account_templates.find_or_create_by!(code: "0750") do |template|
      template.name = "Verbindlichkeiten ggü Gesellschaftern"
      template.account_type = "liability"
    end
  end

  # Use the actual user data as test fixture (with symbol keys as expected by the service)
  let(:balance_sheet_data) do
    {
      aktiva: {
        total: 1095.79,
        anlagevermoegen: [],
        umlaufvermoegen: [
          { balance: 1093.08, account_code: "1529", account_name: "Rückforderungen USt" },
          { balance: 2.71, account_code: "1200", account_name: "Bank" }
        ]
      },
      passiva: {
        total: 1095.79,
        eigenkapital: [
          { balance: 4000, account_code: "0800", account_name: "Gezeichnetes Kapital" },
          { balance: -1348.84, account_code: "0868", account_name: "Verlustvortrag" },
          { balance: -2255.37, account_code: "9805", account_name: "Fehlbetrag" }
        ],
        fremdkapital: [
          { balance: 700, account_code: "0750", account_name: "Verbindlichkeiten ggü Gesellschaftern" }
        ]
      },
      balanced: true
    }
  end

  let(:creator) do
    OpeningBalanceCreator.new(
      fiscal_year: fiscal_year_2021,
      balance_data: balance_sheet_data,
      source: "carryforward"
    )
  end

  describe "#call" do
    context "with valid balance sheet data" do
      it "creates a journal entry with correct line items", focus: true do
        result = creator.call

        expect(result.success?).to be true
        expect(result.data[:journal_entry]).to be_present
        expect(result.data[:balance_sheet]).to be_present

        journal_entry = result.data[:journal_entry]
        expect(journal_entry.line_items.count).to be > 0
        expect(journal_entry.entry_type).to eq("opening")
        expect(journal_entry.sequence).to eq(0)
      end

      it "creates line items for all accounts from balance sheet" do
        result = creator.call
        journal_entry = result.data[:journal_entry]

        # Should have line items for:
        # - 2 umlaufvermoegen accounts (Bank, Rückforderungen USt)
        # - 3 eigenkapital accounts (Gezeichnetes Kapital, Verlustvortrag, guv)
        # - 1 fremdkapital account (Verbindlichkeiten)
        # - 2 EBK balancing entries (debit and credit)
        # = 8 total line items
        expect(journal_entry.line_items.count).to eq(8)

        # Check specific accounts are present
        account_codes = journal_entry.line_items.map { |li| li.account.code }
        expect(account_codes).to include("1529", "1200", "0800", "0868", "9805", "0750", "9000")
      end

      it "balances debits and credits" do
        result = creator.call
        journal_entry = result.data[:journal_entry]

        total_debits = journal_entry.line_items.where(direction: "debit").sum(:amount)
        total_credits = journal_entry.line_items.where(direction: "credit").sum(:amount)

        expect((total_debits - total_credits).abs).to be < 0.01
      end

      it "handles negative balances (losses) correctly" do
        result = creator.call
        journal_entry = result.data[:journal_entry]

        # Verlustvortrag (0868) has balance -1348.84, so it should be DEBITED
        verlustvortrag_line = journal_entry.line_items.joins(:account).find_by(accounts: { code: "0868" })
        expect(verlustvortrag_line).to be_present
        expect(verlustvortrag_line.direction).to eq("debit")
        expect(verlustvortrag_line.amount).to eq(1348.84)

        # Fehlbetrag (guv/9805) has balance -2255.37, so it should be DEBITED
        fehlbetrag_line = journal_entry.line_items.joins(:account).find_by(accounts: { code: "9805" })
        expect(fehlbetrag_line).to be_present
        expect(fehlbetrag_line.direction).to eq("debit")
        expect(fehlbetrag_line.amount).to eq(2255.37)
      end

      it "creates EBK balancing entries on account 9000" do
        result = creator.call
        journal_entry = result.data[:journal_entry]

        ebk_lines = journal_entry.line_items.joins(:account).where(accounts: { code: "9000" })
        expect(ebk_lines.count).to eq(2) # One debit, one credit

        ebk_debit = ebk_lines.find_by(direction: "debit")
        ebk_credit = ebk_lines.find_by(direction: "credit")

        expect(ebk_debit).to be_present
        expect(ebk_credit).to be_present
      end

      it "posts the journal entry and balance sheet" do
        result = creator.call

        journal_entry = result.data[:journal_entry]
        balance_sheet = result.data[:balance_sheet]

        expect(journal_entry.posted_at).to be_present
        expect(balance_sheet.posted_at).to be_present
        expect(fiscal_year_2021.reload.opening_balance_posted_at).to be_present
      end

      it "creates a balance sheet record with correct data" do
        result = creator.call
        balance_sheet = result.data[:balance_sheet]

        expect(balance_sheet.sheet_type).to eq("opening")
        expect(balance_sheet.source).to eq("carryforward")
        expect(balance_sheet.balance_date).to eq(fiscal_year_2021.start_date)
        expect(balance_sheet.data).to eq(balance_sheet_data)
      end
    end

    context "with invalid data" do
      it "fails when balance sheet doesn't balance" do
        unbalanced_data = balance_sheet_data.deep_dup
        unbalanced_data[:passiva][:total] = 9999.99

        creator = OpeningBalanceCreator.new(
          fiscal_year: fiscal_year_2021,
          balance_data: unbalanced_data,
          source: "carryforward"
        )

        result = creator.call
        expect(result.success?).to be false
        expect(result.errors).to include(/does not equal/)
      end

      it "fails when aktiva section is missing" do
        invalid_data = { passiva: balance_sheet_data[:passiva] }

        creator = OpeningBalanceCreator.new(
          fiscal_year: fiscal_year_2021,
          balance_data: invalid_data,
          source: "manual"
        )

        result = creator.call
        expect(result.success?).to be false
        expect(result.errors).to include(/missing aktiva or passiva/)
      end
    end
  end
end
