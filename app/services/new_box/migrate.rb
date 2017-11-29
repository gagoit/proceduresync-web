require 'boxr'

class NewBox::Migrate < BaseService
  extend NewBox::Base


  # NewBox::UploadDocument
  # app/services/new_box/upload_document.rb
  # 
  def self.call(company_id)
    if company_id
      company = Company.find(company_id)
      doc_ids = company.documents.pluck(:id)
      versions = Version.where(:document_id.in => doc_ids, :in_new_box.ne => true)
    else
      versions = Version.where(:in_new_box.ne => true)
    end

    versions.each do |version|
      begin
        next if version.blank? || version.file_url.blank? || version.in_new_box

        document_folder = get_document_folder(version.document_id)
        box_doc = client.upload_file_from_url(version.file_url, document_folder, 
                name: "#{version.file_name}-#{version.code}.#{UrlUtility.get_file_extension(version.file_url)}", 
                preflight_check: false)
        box_status = (box_doc.item_status == "active") ? "done" : box_doc.item_status
        # version.update_attributes({box_status: box_status, box_view_id: box_doc.id, in_new_box: true, document_correction: true})
        Version.where(id: version.id).update_all({box_status: box_status, box_view_id: box_doc.id, in_new_box: true})

        if box_status == "done"
          # downLoad_pdf_file(version.id, box_doc, 0)
        else
          # Notification.when_doc_upload_finished(version.reload)
          AppErrors::Create.call(
            version.document.try(:company_id), "migrate_document", 
            "[NewBox::Migrate.call][document_id: #{version.document_id}][version_id: #{version.id}]: box-doc is error"
          )
        end
        puts "#{version.id} -- #{box_status}"
      rescue Exception => e
        puts "NewBox::UploadDocument error: #{version.id} - #{e.message}"
        # version.update_attributes({box_status: "error", document_correction: true})
        Version.where(id: version.id).update_all({box_status: "error", in_new_box: true})
        # Notification.when_doc_upload_finished(version)
        
        AppErrors::Create.call(
          version.document.try(:company_id), "migrate_document", 
          "[NewBox::Migrate.call][document_id: #{version.document_id}][version_id: #{version.id}]: box-doc is error"
        )
      end
    end
  end
end