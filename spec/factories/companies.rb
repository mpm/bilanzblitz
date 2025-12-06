FactoryBot.define do
  factory :company do
    name { Faker::Company.name }
    tax_number { Faker::Number.number(digits: 11).to_s }
    vat_id { "DE#{Faker::Number.number(digits: 9)}" }
    commercial_register_number { "HRB #{Faker::Number.number(digits: 6)}" }
    address { "#{Faker::Address.street_address}, #{Faker::Address.zip_code} #{Faker::Address.city}" }
  end
end
