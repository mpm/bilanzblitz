FactoryBot.define do
  factory :line_item do
    journal_entry
    account { association :account, company: journal_entry.company }
    amount { Faker::Commerce.price(range: 1.0..1000.0) }
    direction { "debit" }

    trait :debit do
      direction { "debit" }
    end

    trait :credit do
      direction { "credit" }
    end

    trait :with_bank_transaction do
      bank_transaction
    end
  end
end
