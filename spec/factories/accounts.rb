FactoryBot.define do
  factory :account do
    company
    sequence(:code) { |n| (1200 + n).to_s }
    name { "#{Faker::Commerce.department} Account" }
    account_type { "asset" }
    tax_rate { 0.0 }
    is_system_account { false }

    trait :asset do
      account_type { "asset" }
      code { "1200" }
      name { "Bank Account" }
    end

    trait :liability do
      account_type { "liability" }
      code { "3000" }
      name { "Trade Payables" }
    end

    trait :equity do
      account_type { "equity" }
      code { "2000" }
      name { "Share Capital" }
    end

    trait :revenue do
      account_type { "revenue" }
      code { "4000" }
      name { "Sales Revenue" }
    end

    trait :expense do
      account_type { "expense" }
      code { "6000" }
      name { "Operating Expenses" }
    end

    trait :with_vat_19 do
      tax_rate { 19.0 }
      name { "Input Tax 19%" }
      code { "1576" }
    end

    trait :with_vat_7 do
      tax_rate { 7.0 }
      name { "Input Tax 7%" }
      code { "1571" }
    end

    trait :system_account do
      is_system_account { true }
    end
  end
end
