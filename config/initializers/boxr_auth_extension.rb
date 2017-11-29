module Boxr
  
  ##
  # https://developer.box.com/docs/getting-started-with-new-box-view#section-retrieve-a-file-token-using-token-exchange-optional
  # Requesting a File Scoped Token
  ##
  def self.get_file_scoped_token(file_id, subject_token, scope: "item_preview")
    uri = "https://api.box.com/oauth2/token"
    body = "subject_token=#{subject_token}"
    body << "&subject_token_type=urn:ietf:params:oauth:token-type:access_token"
    body << "&scope=#{scope}"
    body << "&resource=https://api.box.com/2.0/files/#{file_id}"
    body << "&grant_type=urn:ietf:params:oauth:grant-type:token-exchange"

    auth_post(uri, body)
  end

end