# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :user do
    sequence(:email){|n|"email#{n}@abc.com"}
    password "Phambadat123456789"
    password_confirmation "Phambadat123456789"

    sequence(:name){|n|"Admin#{n}@abc.com"}

    token User.access_token

    admin true
    active true
  end
end
