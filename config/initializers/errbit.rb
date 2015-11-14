Airbrake.configure do |config|
  config.api_key     = 'c31ef80aa09d9cfc3755bcc9a3b1e390'
  config.host        = 'errbit.appiphany.com.au'
  config.port        = 80
  config.secure      = config.port == 443
end