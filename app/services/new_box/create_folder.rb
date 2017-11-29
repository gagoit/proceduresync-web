##
# Box V2 Content API
##
require 'boxr'

class NewBox::CreateFolder < BaseService
  extend NewBox::Base

  def self.call name, parent=nil
    begin
      parent ||= Boxr::ROOT
      client.create_folder(name, parent)
    rescue Exception => e
      puts "NewBox::CreateFolder.call error: #{e.message}"
    end
  end
end