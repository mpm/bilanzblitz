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
end
