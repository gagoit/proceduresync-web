##
# Box V2 Content API
##
require 'boxr'

class NewBox::GetFileToken < BaseService
  extend NewBox::Base

  ##
  # Get file scoped token for previewing
  # https://developer.box.com/docs/getting-started-with-new-box-view#section-retrieve-a-file-token-using-token-exchange-optional
  # A File Token is valid up to 60 minutes from the time it is generated.
  ##
  def self.call(file_id, scope: "item_preview")
    begin
      Rails.cache.fetch("box_file_scoped_token_#{file_id}", expires_in: 55.minutes) do  
        Boxr::get_file_scoped_token(file_id, CONFIG[:box_view_access_token], scope: scope).access_token
      end
    rescue Exception => e
      BaseService.notify_or_ignore_error(e)
    end
  end
end