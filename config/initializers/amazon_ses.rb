ActionMailer::Base.add_delivery_method :ses, AWS::SES::Base,
  access_key_id: CONFIG['amazon_access_key'],
  secret_access_key: CONFIG['amazon_secret']
