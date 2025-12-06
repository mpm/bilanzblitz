FactoryBot.define do
  factory :bank_account do
    company
    iban { Faker::Bank.iban(country_code: "DE") }
    bic { Faker::Bank.swift_bic }
    bank_name { Faker::Bank.name }
    currency { "EUR" }
    ledger_account { association :account, :asset, company: company }
  end
end
