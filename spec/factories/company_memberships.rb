FactoryBot.define do
  factory :company_membership do
    user
    company
    role { "accountant" }

    trait :admin do
      role { "admin" }
    end

    trait :viewer do
      role { "viewer" }
    end
  end
end
