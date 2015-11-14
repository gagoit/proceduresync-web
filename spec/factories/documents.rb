# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :document do
    sequence(:title){|n| "Document Title #{n}"}
    sequence(:doc_id){|n| "Doc ID #{n}"}

    expiry (Time.now.utc + 1.day)
    effective_time (Time.now.utc - 1.day)

    active true
    is_private false
    created_time (Time.now.utc + 1.day)
    restricted false
  end
end
