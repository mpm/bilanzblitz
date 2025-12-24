# frozen_string_literal: true

# Helper class to represent a Report Section (Berichtsposition) with nested structure.
# Provides both hierarchical view and flattened accounts for reporting purposes.
#
# @example Basic usage
#   section = BalanceSheetSection.new(
#     section_key: :anlagevermoegen,
#     section_name: "Anlagevermögen",
#     level: 1,
#     accounts: [{ code: "0100", name: "Account", balance: 1000.0 }]
#   )
#   section.add_child(child_section)
#   section.total # => 1000.0 + child totals
#
class BalanceSheetSection
  attr_reader :section_key, :section_name, :level, :children
  attr_accessor :accounts

  # Create an empty section with just a key
  # @param section_key [Symbol] The section identifier
  # @return [BalanceSheetSection] An empty section
  def self.empty(section_key)
    new(
      section_key: section_key,
      section_name: AccountMap.category_name(section_key) || section_key.to_s,
      level: 1,
      accounts: []
    )
  end

  # @param section_key [Symbol] The section identifier (e.g., :anlagevermoegen)
  # @param section_name [String] The German name from JSON (e.g., "Anlagevermögen")
  # @param level [Integer] The nesting level (top-level = 1)
  # @param accounts [Array<Hash>] Accounts at this level only (with :code, :name, :balance keys)
  def initialize(section_key:, section_name:, level: 1, accounts: [])
    @section_key = section_key
    @section_name = section_name
    @level = level
    @accounts = accounts
    @children = []
  end

  # Add a child section
  # @param child [BalanceSheetSection] The child section to add
  # @return [BalanceSheetSection] Returns self for chaining
  def add_child(child)
    @children << child
    self
  end

  # Get all accounts at this level only (not including children)
  # @return [Array<Hash>] Array of account hashes
  def own_accounts
    @accounts
  end

  # Get all accounts including from all descendant subsections
  # @return [Array<Hash>] Flattened array of account hashes
  def flattened_accounts
    result = @accounts.dup
    @children.each do |child|
      result.concat(child.flattened_accounts)
    end
    result
  end

  # Calculate sum of account balances at this level only
  # @return [Float] Sum of balances
  def own_total
    @accounts.sum { |account| account[:balance] }
  end

  # Calculate total including all children recursively
  # @return [Float] Total sum including all descendants
  def total
    own_total + @children.sum(&:total)
  end

  # Check if this section has any accounts (at any level)
  # @return [Boolean]
  def empty?
    @accounts.empty? && @children.all?(&:empty?)
  end

  # Get number of accounts at this level only
  # @return [Integer]
  def account_count
    @accounts.size
  end

  # Get total number of accounts including all children
  # @return [Integer]
  def total_account_count
    @accounts.size + @children.sum(&:total_account_count)
  end

  # Convert to hash representation (for JSON serialization)
  # @param include_children [Boolean] Whether to include children in output
  # @return [Hash]
  def to_h(include_children: true)
    result = {
      section_key: @section_key,
      section_name: @section_name,
      level: @level,
      accounts: @accounts.map(&:dup),
      own_total: own_total.round(2),
      total: total.round(2),
      account_count: account_count,
      total_account_count: total_account_count
    }

    if include_children && @children.any?
      result[:children] = @children.map { |child| child.to_h(include_children: true) }
    end

    result
  end

  # Find a child section by key (non-recursive)
  # @param key [Symbol] The section key to find
  # @return [BalanceSheetSection, nil]
  def find_child(key)
    @children.find { |child| child.section_key == key }
  end

  # Find a section by key recursively (depth-first search)
  # @param key [Symbol] The section key to find
  # @return [BalanceSheetSection, nil]
  def find_section(key)
    return self if @section_key == key

    @children.each do |child|
      found = child.find_section(key)
      return found if found
    end

    nil
  end
end
