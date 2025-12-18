FactoryBot.define do
  factory :balance_sheet do
    fiscal_year
    sheet_type { "closing" }
    source { "calculated" }
    balance_date { fiscal_year.end_date }
    data do
      {
        aktiva: {
          anlagevermoegen: [],
          umlaufvermoegen: [],
          total: 0.0
        },
        passiva: {
          eigenkapital: [],
          fremdkapital: [],
          total: 0.0
        },
        guv: {
          net_income: 0.0
        }
      }.with_indifferent_access
    end
    posted_at { nil }

    trait :opening do
      sheet_type { "opening" }
      source { "manual" }
      balance_date { fiscal_year.start_date }
    end

    trait :closing do
      sheet_type { "closing" }
      source { "calculated" }
      balance_date { fiscal_year.end_date }
    end

    trait :posted do
      posted_at { Time.current }
    end

    trait :with_carryforward do
      source { "carryforward" }
    end
  end
end
