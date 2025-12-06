FactoryBot.define do
  factory :fiscal_year do
    company
    year { Date.current.year }
    start_date { Date.new(year, 1, 1) }
    end_date { Date.new(year, 12, 31) }
    closed { false }

    trait :closed do
      closed { true }
      closed_at { Time.current }
      balance_sheet_snapshot { { assets: 100000, liabilities: 50000, equity: 50000 } }
    end
  end
end
