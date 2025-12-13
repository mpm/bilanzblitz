require 'rails_helper'

RSpec.describe JournalEntryCreator do
  describe "#call" do
    it "returns an error when fiscal year is closed"
    it "creates the journal entry when fiscal year is open"
    it "creates the fiscal year if it doesn't exist yet"
  end
end
