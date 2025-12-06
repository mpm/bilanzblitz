FactoryBot.define do
  factory :bank_transaction do
    bank_account
    booking_date { Date.current }
    value_date { Date.current }
    amount { Faker::Commerce.price(range: -1000.0..1000.0) }
    currency { "EUR" }
    sequence(:remote_transaction_id) { |n| "TXN#{Date.current.strftime('%Y%m%d')}#{n.to_s.rjust(6, '0')}" }
    remittance_information { Faker::Lorem.sentence }
    counterparty_name { Faker::Company.name }
    counterparty_iban { Faker::Bank.iban(country_code: "DE") }
    status { "pending" }

    trait :booked do
      status { "booked" }
    end

    trait :reconciled do
      status { "reconciled" }
    end

    trait :incoming do
      amount { Faker::Commerce.price(range: 100.0..1000.0) }
    end

    trait :outgoing do
      amount { -Faker::Commerce.price(range: 100.0..1000.0) }
    end
  end
end
