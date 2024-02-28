# frozen_string_literal: true

FactoryBot.define do
  # Deliberately uses the same figures as the "Chestnut Ridge" seed so the
  # numbers in the specs, the seeds and the README all describe one deal.
  factory :loan_request do
    sequence(:address) { |n| "#{1400 + n} Chestnut Ridge Rd, Durham, NC 27703" }
    product_code { 'fix_and_flip' }
    loan_term { 6 }
    purchase_price { 215_000 }
    repair_budget { 48_000 }
    arv { 340_000 }
    first_name { 'Dana' }
    last_name { 'Whitfield' }
    sequence(:email) { |n| "dana#{n}@ridgelinehomes.co" }
    phone { '(919) 555-0142' }

    trait :rendered do
      status { 'rendered' }
      after(:create) do |loan_request|
        loan_request.term_sheet.attach(
          io: StringIO.new('%PDF-1.4 test'),
          filename: 'termsheet.pdf',
          content_type: 'application/pdf'
        )
      end
    end

    trait :delivered do
      rendered
      status { 'delivered' }
      delivered_at { Time.current }
    end
  end
end
