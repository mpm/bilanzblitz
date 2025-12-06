FactoryBot.define do
  factory :document do
    company
    sequence(:document_number) { |n| "INV-#{Date.current.year}-#{n.to_s.rjust(5, '0')}" }
    document_date { Date.current }
    document_type { "invoice" }
    total_amount { Faker::Commerce.price(range: 100.0..10000.0) }

    trait :invoice do
      document_type { "invoice" }
    end

    trait :receipt do
      document_type { "receipt" }
    end

    trait :credit_note do
      document_type { "credit_note" }
    end

    trait :contract do
      document_type { "contract" }
    end
  end
end
