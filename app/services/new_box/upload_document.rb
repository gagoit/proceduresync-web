##
# Box V2 Content API
##
require 'boxr'

class NewBox::UploadDocument < BaseService
  extend NewBox::Base

  ##
  # Upload document to Box-View
  # TODO: Use Chunked Upload API when file is large: https://developer.box.com/reference#supercharged-upload
  ##
  def self.call(version_id)
    begin
      version = Version.find(version_id) rescue nil
      return if version.blank? || version.file_url.blank?

      document_folder = get_document_folder(version.document_id)
      doc = client.upload_file_from_url(version.file_url, document_folder, 
              name: "#{version.file_name}-#{version.code}.#{UrlUtility.get_file_extension(version.file_url)}", 
              preflight_check: false)
      box_status = (doc.item_status == "active") ? "done" : doc.item_status
      version.update_attributes({box_status: box_status, box_view_id: doc.id, in_new_box: true})

      if box_status == "done"
        NewBox::DownloadPdfFile.call(version_id, doc, 0)
      else
        Notification.when_doc_upload_finished(version.reload)

        AppErrors::Create.call(
          version.document.try(:company_id), "upload_document", 
          "[NewBox::UploadDocument.call][document_id: #{version.document_id}][version_id: #{version.id}] box_status is error"
        )
      end
    rescue Exception => e
      version.update_attributes({box_status: "error"})
      Notification.when_doc_upload_finished(version)
      
      AppErrors::Create.call(
        version.document.try(:company_id), "upload_document", 
        "[NewBox::UploadDocument.call][document_id: #{version.document_id}][version_id: #{version.id}] Exception: #{e.message} | At: #{get_first_line_num_in_exception(e)}"
      )
    end
  end
end