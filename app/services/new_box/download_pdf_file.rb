##
# Box V2 Content API
##
require 'boxr'

class NewBox::DownloadPdfFile < BaseService
  extend NewBox::Base

  ##
  # Download file from box and upload it to s3
  # also export thumbnail (png) of document
  ##
  def self.call(version_id, box_doc, num_call = 0)
    begin
      version = version_id.is_a?(Version) ? version_id : Version.find(version_id)
      doc = version.document
      file_name = "tmp/#{version.document_id}-#{version.id}.pdf"
      file_name_encrypted = "tmp/#{version.document_id}-#{version.id}-encrypted.pdf"
      file_png_name = "tmp/#{version.document_id}-#{version.id}.png"
      
      if UrlUtility.get_file_extension(version.file_url) == "pdf"
        open(file_name, 'w', encoding: 'ASCII-8BIT') do |f|
          f << open(version.file_url).read
        end
      else
        f = File.open(file_name, 'w', encoding: 'ASCII-8BIT')
        f.write(client.download_pdf(box_doc))
        f.flush
        f.close
      end

      ## Get content of file
      if doc && doc.current_version.try(:id) == version.id
        pdf = Grim.reap(file_name)         # returns Grim::Pdf instance for pdf
        d_content = DocumentContent.find_or_initialize_by({document_id: version.document_id})
        d_content.title = doc.title
        d_content.doc_id = doc.doc_id
        d_content.company_id = doc.company_id
        d_content.pages = pdf.map { |e| e.text }
        d_content.save

        file_txt_name = "tmp/#{version.document_id}-#{version.id}.txt"
        file_txt_name_encrypted = "tmp/#{version.document_id}-#{version.id}-encrypted.txt"

        f_t = File.open(file_txt_name, 'w', encoding: 'ASCII-8BIT')
        f_t.write(d_content.pages.join(" "))
        f_t.flush
        f_t.close

        # encrypt txt file
        XOREncrypt.encrypt_decrypt(file_txt_name, doc.id.to_s, file_txt_name_encrypted, 4)
        DocumentService.upload_file_to_s3(version, file_txt_name_encrypted, "txt")

        # get thumbnail
        pdf[0].save(file_png_name)

        version.image = File.open(file_png_name, 'r')
        version.text_file_size = File.size(file_txt_name)
      end

      version.box_file_size = File.size(file_name)
      version.save

      # #encrypt file
      XOREncrypt.encrypt_decrypt(file_name, doc.try(:company_id).to_s, file_name_encrypted)

      DocumentService.upload_file_to_s3(version, file_name_encrypted, "pdf")
    rescue Exception => e
      if num_call < 3
        return self.call(version_id, box_doc, (num_call + 1)) 
      end

      AppErrors::Create.call(
        doc.try(:company_id), "upload_document", 
        "[NewBox::DownloadPdfFile.call][document_id: #{version.document_id}][version_id: #{version_id}] Exception: #{e.message} | At: #{get_first_line_num_in_exception(e)}"
      )
    end
  end
end