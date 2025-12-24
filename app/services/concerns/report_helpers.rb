# frozen_string_literal: true

# ReportHelpers provides shared utility methods for report services
# (BalanceSheet, GuV, Tax Reports, etc.)
#
# This concern contains methods for extracting and manipulating data from
# nested balance sheet and GuV structures.
module ReportHelpers
  # Recursively extract all accounts from nested balance sheet sections
  # Handles the nested BalanceSheetSection structure with children
  #
  # NOTE: This method deduplicates accounts by code, keeping the first occurrence.
  # This is necessary because some balance sheet structures incorrectly include
  # the same account at multiple nesting levels.
  #
  # @param sections_hash [Hash] Hash of section_key => BalanceSheetSection data
  # @return [Array<Hash>] Flat array of unique account hashes with :code, :name, :balance keys
  #
  # @example
  #   sections = {
  #     anlagevermoegen: {
  #       accounts: [{ code: "0100", name: "...", balance: 1000.0 }],
  #       children: [
  #         { accounts: [{ code: "0200", name: "...", balance: 500.0 }], children: [] }
  #       ]
  #     }
  #   }
  #   extract_accounts_from_sections(sections)
  #   # => [{ code: "0100", ... }, { code: "0200", ... }]
  def extract_accounts_from_sections(sections_hash)
    return [] unless sections_hash

    accounts = []
    sections_hash.each_value do |section|
      # Add accounts from this section
      accounts.concat(section[:accounts]) if section[:accounts]

      # Recursively add accounts from children
      if section[:children] && section[:children].any?
        section[:children].each do |child_section|
          accounts.concat(extract_accounts_from_section(child_section))
        end
      end
    end

    accounts
  end

  # Recursively extract accounts from a single section
  # Helper method for extract_accounts_from_sections
  #
  # @param section [Hash] A single BalanceSheetSection hash
  # @return [Array<Hash>] Flat array of account hashes from this section and all children
  def extract_accounts_from_section(section)
    accounts = section[:accounts] || []

    if section[:children] && section[:children].any?
      section[:children].each do |child_section|
        accounts.concat(extract_accounts_from_section(child_section))
      end
    end

    accounts
  end

  # Add net_income as pseudo account to eigenkapital section
  # Mutates the sections_hash in place
  #
  # @param sections_hash [Hash] The passiva sections hash (will be modified)
  # @param net_income [Float] The net income amount
  # @return [Hash] The modified sections_hash
  #
  # @example
  #   passiva_sections = { eigenkapital: {...}, verbindlichkeiten: {...} }
  #   add_net_income_to_eigenkapital!(passiva_sections, 5000.0)
  #   # => passiva_sections[:eigenkapital][:accounts] now includes net_income pseudo account
  def add_net_income_to_eigenkapital!(sections_hash, net_income)
    return sections_hash unless sections_hash.is_a?(Hash)
    return sections_hash if net_income.abs < 0.01  # Skip if zero

    eigenkapital_section = sections_hash[:eigenkapital]
    return sections_hash unless eigenkapital_section

    # Duplicate accounts array to avoid mutating frozen arrays
    eigenkapital_section[:accounts] = eigenkapital_section[:accounts].dup

    # Add net_income pseudo account
    eigenkapital_section[:accounts] << {
      code: "net_income",
      name: net_income >= 0 ? "Jahresüberschuss" : "Jahresfehlbetrag",
      type: "equity",
      balance: net_income
    }

    # Update totals and counts
    eigenkapital_section[:own_total] = (eigenkapital_section[:own_total] || 0) + net_income
    eigenkapital_section[:total] = (eigenkapital_section[:total] || 0) + net_income
    eigenkapital_section[:account_count] += 1
    eigenkapital_section[:total_account_count] += 1

    sections_hash
  end

  # Calculate total from all nested sections recursively
  #
  # @param sections_hash [Hash] Hash of section_key => section data
  # @return [Float] Total sum of all section totals
  #
  # @example
  #   sections = { anlagevermoegen: {total: 1000}, umlaufvermoegen: {total: 500} }
  #   calculate_sections_total(sections) # => 1500.0
  def calculate_sections_total(sections_hash)
    return 0.0 unless sections_hash.is_a?(Hash)

    sections_hash.values.sum { |section| section[:total].to_f }
  end
end
