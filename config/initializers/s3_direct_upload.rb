S3DirectUpload.config do |c|
  c.access_key_id = CONFIG['amazon_access_key']       # your access key id
  c.secret_access_key = CONFIG['amazon_secret']   # your secret access key
  c.bucket = CONFIG[:bucket]              # your bucket name
  c.region = "ap-southeast-2"             # region prefix of your bucket url (optional), eg. "s3-eu-west-1"
  c.url = "https://#{c.bucket}.s3.amazonaws.com/"                # S3 API endpoint (optional), eg. "https://#{c.bucket}.s3.amazonaws.com/"
end