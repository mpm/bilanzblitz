FactoryBot.define do
  factory :tax_report do
    company
    period_type { "monthly" }
    start_date { Date.current.beginning_of_month }
    end_date { Date.current.end_of_month }
    status { "draft" }

    trait :monthly do
      period_type { "monthly" }
    end

    trait :quarterly do
      period_type { "quarterly" }
      start_date { Date.current.beginning_of_quarter }
      end_date { Date.current.end_of_quarter }
    end

    trait :annual do
      period_type { "annual" }
      start_date { Date.current.beginning_of_year }
      end_date { Date.current.end_of_year }
    end

    trait :submitted do
      status { "submitted" }
      submitted_at { Time.current }
      elster_transmission_id { "ELSTER-#{Faker::Alphanumeric.alphanumeric(number: 10).upcase}" }
      generated_data { { total_vat: 1900.0, total_revenue: 10000.0 } }
    end

    trait :accepted do
      status { "accepted" }
      submitted_at { 1.week.ago }
      elster_transmission_id { "ELSTER-#{Faker::Alphanumeric.alphanumeric(number: 10).upcase}" }
      generated_data { { total_vat: 1900.0, total_revenue: 10000.0 } }
    end
  end
end
