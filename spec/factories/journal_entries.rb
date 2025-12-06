FactoryBot.define do
  factory :journal_entry do
    company
    fiscal_year { association :fiscal_year, company: company }
    booking_date { Date.current }
    description { Faker::Lorem.sentence }
    posted_at { nil }

    trait :posted do
      posted_at { Time.current }
    end

    trait :with_document do
      document { association :document, company: company }
    end

    trait :with_balanced_line_items do
      after(:create) do |journal_entry|
        company = journal_entry.company
        debit_account = create(:account, :expense, company: company)
        credit_account = create(:account, :asset, company: company)

        create(:line_item, journal_entry: journal_entry, account: debit_account, amount: 100.0, direction: "debit")
        create(:line_item, journal_entry: journal_entry, account: credit_account, amount: 100.0, direction: "credit")
      end
    end
  end
end
