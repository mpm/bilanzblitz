# frozen_string_literal: true

# FiscalYearImporter - Imports historical fiscal years with manual closing balance sheets
#
# This service is used when you want to import a fiscal year from the past where you
# don't have transaction history, but you do have the closing balance sheet data.
#
# Usage:
#   importer = FiscalYearImporter.new(
#     company: company,
#     year: 2023,
#     balance_sheet_data: {
#       aktiva: {
#         anlagevermoegen: [{ account_code: "0210", account_name: "Geschäftsausstattung", balance: 5000.0 }],
#         umlaufvermoegen: [{ account_code: "1200", account_name: "Bank", balance: 10000.0 }],
#         total: 15000.0
#       },
#       passiva: {
#         eigenkapital: [{ account_code: "2000", account_name: "Gezeichnetes Kapital", balance: 15000.0 }],
#         rueckstellungen: [],
#         verbindlichkeiten: [],
#         total: 15000.0
#       },
#       balanced: true
#     }
#   )
#   result = importer.call
#
class FiscalYearImporter
  include ReportHelpers

  attr_reader :company, :year, :balance_sheet_data, :net_income, :errors

  def initialize(company:, year:, balance_sheet_data:, net_income: 0.0)
    @company = company
    @year = year.to_i
    @balance_sheet_data = balance_sheet_data
    @net_income = net_income.to_f
    @errors = []
  end

  def call
    # Transform balance sheet BEFORE validation
    transform_balance_sheet!

    validate!
    return false unless @errors.empty?

    ActiveRecord::Base.transaction do
      create_fiscal_year!
      create_closing_balance_sheet!
      close_fiscal_year!
    end

    true
  rescue StandardError => e
    @errors << e.message
    false
  end

  private

  def validate!
    # Validate year
    if @year < 1900 || @year > 2100
      @errors << "Year must be between 1900 and 2100"
    end

    # Check if fiscal year already exists
    if @company.fiscal_years.exists?(year: @year)
      @errors << "Fiscal year #{@year} already exists"
    end

    # Validate balance sheet data structure
    unless @balance_sheet_data.is_a?(Hash)
      @errors << "Balance sheet data must be a hash"
      return
    end

    # Validate that balance sheet balances
    unless balance_sheet_balanced?
      @errors << "Balance sheet does not balance. Aktiva must equal Passiva."
    end
  end

  def balance_sheet_balanced?
    # After transform_balance_sheet!, totals are already calculated correctly
    # (including net_income in eigenkapital section)
    return false unless @balance_sheet_data[:aktiva].is_a?(Hash)
    return false unless @balance_sheet_data[:passiva].is_a?(Hash)

    aktiva_total = @balance_sheet_data[:aktiva][:total].to_f
    passiva_total = @balance_sheet_data[:passiva][:total].to_f

    (aktiva_total - passiva_total).abs < 0.01
  end

  def create_fiscal_year!
    start_date = Date.new(@year, 1, 1)
    end_date = Date.new(@year, 12, 31)

    @fiscal_year = @company.fiscal_years.create!(
      year: @year,
      start_date: start_date,
      end_date: end_date,
      closed: false
    )
  end

  def create_closing_balance_sheet!
    # Convert flat structure to nested structure for consistency with BalanceSheetService
    nested_data = convert_to_nested_structure(@balance_sheet_data)

    @balance_sheet = @fiscal_year.balance_sheets.create!(
      sheet_type: "closing",
      source: "manual",
      balance_date: @fiscal_year.end_date,
      data: nested_data,
      posted_at: Time.current
    )
  end

  def close_fiscal_year!
    @fiscal_year.update!(
      closing_balance_posted_at: Time.current,
      closed: true,
      closed_at: Time.current
    )
  end

  # Transform balance sheet data to match BalanceSheetService format:
  # 1. Convert flat structure to nested sections
  # 2. Add net_income pseudo account to Eigenkapital
  # 3. Calculate totals from nested accounts (not from input)
  def transform_balance_sheet!
    # Convert to nested structure first
    @balance_sheet_data = {
      aktiva: {
        sections: build_nested_sections(@balance_sheet_data[:aktiva], :aktiva)
      },
      passiva: {
        sections: build_nested_sections(@balance_sheet_data[:passiva], :passiva)
      }
    }

    # Add net_income pseudo account to eigenkapital section
    add_net_income_to_eigenkapital!(@balance_sheet_data[:passiva][:sections], @net_income)

    # Calculate totals from nested sections (passiva_total now includes net_income)
    @balance_sheet_data[:aktiva][:total] = calculate_sections_total(@balance_sheet_data[:aktiva][:sections])
    @balance_sheet_data[:passiva][:total] = calculate_sections_total(@balance_sheet_data[:passiva][:sections])
  end

  # Wrap transformed balance sheet data with metadata
  # Data is already in nested format from transform_balance_sheet!
  def convert_to_nested_structure(transformed_data)
    {
      fiscal_year: {
        id: @fiscal_year.id,
        year: @fiscal_year.year,
        start_date: @fiscal_year.start_date,
        end_date: @fiscal_year.end_date,
        closed: @fiscal_year.closed
      },
      aktiva: transformed_data[:aktiva],
      passiva: transformed_data[:passiva],
      balanced: true,  # Already validated
      net_income: @net_income,
      guv_data: nil
    }
  end

  # Build nested section structures for a given side (aktiva or passiva)
  def build_nested_sections(side_data, side)
    sections = {}

    # Get top-level categories for this side from AccountMap
    categories = AccountMap.nested_balance_sheet_categories[side]

    categories.each do |category_key, _category_structure|
      # Get flat accounts for this category from imported data
      flat_accounts = side_data[category_key] || []

      next if flat_accounts.empty?

      # Convert flat account format to AccountMap format
      account_list = flat_accounts.map do |acc|
        {
          code: acc[:account_code] || acc["account_code"],
          name: acc[:account_name] || acc["account_name"],
          type: infer_account_type(side, category_key),
          balance: (acc[:balance] || acc["balance"]).to_f
        }
      end

      # Build nested section structure using AccountMap
      section = AccountMap.build_nested_section(account_list, category_key)
      section_hash = section.to_h

      # AccountMap filters out accounts not in SKR03 mapping
      # For imported data, we need to preserve all accounts, so add any missing ones
      section_account_codes = collect_account_codes(section_hash)
      missing_accounts = account_list.reject { |acc| section_account_codes.include?(acc[:code]) }

      if missing_accounts.any?
        # Add missing accounts to the top level of this section
        section_hash[:accounts] = (section_hash[:accounts] || []) + missing_accounts
        section_hash[:own_total] = (section_hash[:own_total] || 0) + missing_accounts.sum { |acc| acc[:balance] }
        section_hash[:total] = (section_hash[:total] || 0) + missing_accounts.sum { |acc| acc[:balance] }
        section_hash[:account_count] += missing_accounts.size
        section_hash[:total_account_count] += missing_accounts.size
      end

      sections[category_key] = section_hash
    end

    sections
  end

  # Collect all account codes from a section hash (including children)
  def collect_account_codes(section_hash)
    codes = (section_hash[:accounts] || []).map { |acc| acc[:code] }

    if section_hash[:children]
      section_hash[:children].each do |child|
        codes.concat(collect_account_codes(child))
      end
    end

    codes
  end

  # Infer account type from side and category
  def infer_account_type(side, category_key)
    if side == :aktiva
      "asset"
    elsif category_key == :eigenkapital
      "equity"
    else
      "liability"
    end
  end
end
