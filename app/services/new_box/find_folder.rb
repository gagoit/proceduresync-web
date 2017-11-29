##
# Box V2 Content API
##
require 'boxr'

class NewBox::FindFolder < BaseService
  extend NewBox::Base

  def self.call name_or_id
    begin
      if name_or_id.is_a?(Integer)
        client.folder_from_id(name_or_id)
      else
        client.folder_from_path(name_or_id)
      end
    rescue Exception => e
      puts "NewBox::FindFolder.call error: #{e.message}"
    end
  end
end