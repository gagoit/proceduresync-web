##
# Box V2 Content API
##
require 'boxr'

class NewBox::GetConvertedDocument < BaseService
  extend NewBox::Base

  ##
  # Get converted document from Box-View
  # TODO: Use Chunked Upload API when file is large: https://developer.box.com/reference#supercharged-upload
  ##
  def self.call(version_id)
    begin
      version = Version.find(version_id)
      return if version.blank? || version.file_url.blank? || version.box_view_id.blank? || 
        (version.box_status == "done" && version.doc_file) || version.attemps_num_download_converted_file.to_i > Version::MAX_ATTEMPS_NUM_DOWNLOAD

      doc = client.file_from_id(version.box_view_id)
      box_status = (doc.item_status == "active") ? "done" : doc.item_status
      version.update_attributes({
        box_status: box_status, 
        attemps_num_download_converted_file: version.attemps_num_download_converted_file.to_i + 1
      })

      if box_status == "done"
        NewBox::DownloadPdfFile.call(version_id, doc, 0)
      else
        AppErrors::Create.call(
          version.document.try(:company_id), "upload_document", 
          "[NewBox::GetConvertedDocument.call][document_id: #{version.document_id}][version_id: #{version.id}] box_status is error"
        )
      end
    rescue Exception => e
      version.update_attributes({box_status: "error"})
      
      AppErrors::Create.call(
        version.document.try(:company_id), "upload_document", 
        "[NewBox::GetConvertedDocument.call][document_id: #{version.document_id}][version_id: #{version.id}] Exception: #{e.message} | At: #{get_first_line_num_in_exception(e)}"
      )
    end
  end
end