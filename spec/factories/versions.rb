# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :version do
    sequence(:version){|n|"version #{n}"}
    zip_file "google.com"
    doc_file "google.com"
    
    file {fixture_file_upload(Rails.root.join('spec', 'factories', 'test-file.pdf'), 'application/pdf') }

    box_status 'done'
  end
end
