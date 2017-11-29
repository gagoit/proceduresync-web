##
# Box V2 Content API
##
require 'boxr'

class NewBox::GetEmbedUrl < BaseService
  extend NewBox::Base

  ##
  # https://docs.box.com/reference#get-embed-link
  # For security reasons, the generated embed link will expire after 1 minute 
  #   and should be embedded immediately in the app once generated.
  ##
  def self.call(file_id)
    begin
      Rails.cache.fetch("box_embed_url_#{file_id}", :expires_in => 50.seconds) do  
        client.embed_url(file_id, show_download: true)
      end
    rescue Exception => e
      BaseService.notify_or_ignore_error(e)
    end
  end
end