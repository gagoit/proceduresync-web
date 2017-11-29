##
# Box V2 Content API
##
require 'boxr'

class NewBox::GetThumbnail < BaseService
  extend NewBox::Base

  ##
  # Get thumbnail of a doc's version
  ##
  def self.call(version_id, box_doc)
    begin
      version = version_id.is_a?(Version) ? version_id : Version.find(version_id)
      file_name = "tmp/#{version.document_id}-#{version.id}.png"
      f = File.open(file_name, 'w', encoding: 'ASCII-8BIT')
      attemps = 0

      while attemps < 10
        begin
          f.write(client.new_thumbnail(box_doc, "png"))
          f.flush

          attemps = 100
        rescue Exception => e
          attemps += 1

          if attemps == 10
            AppErrors::Create.call(
              version.document.try(:company_id), "upload_document", 
              "[DocumentService.get_thumbnail][document_id: #{version.document_id}][version_id: #{version.id}] Exception: #{e.message} | At: #{get_first_line_num_in_exception(e)}"
            )
          end
        end
      end

      if attemps == 100
        version.image = f
        version.save
      end

      f.close
    rescue Exception => e
      AppErrors::Create.call(
        version.document.try(:company_id), "upload_document", 
        "[NewBox::GetThumbnail.call][document_id: #{version.document_id}][version_id: #{version.id}] Exception: #{e.message} | At: #{get_first_line_num_in_exception(e)}"
      )
    end
  end
end