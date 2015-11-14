class DocumentService < BaseService
	##
  # Upload document to Box-View
  ##
  def self.upload_to_box(version)
    begin
      return if version.blank? || version.file_url.blank?

      doc = BoxView::Api::Document.new.upload(version.file_url, "#{version.file_name}-#{version.code}")

      attemps = 0
      while (doc.status != "done" && doc.status != "error" )
        attemps += 1

        sleep 3
        doc = doc.reload
        puts "version: #{version.id} - attemps: #{attemps} - status: #{doc.status}"

        break if attemps > 100
      end

      version.update_attributes({box_status: doc.status, box_view_id: doc.id})

      if doc.status == "done"
        download_zipfile_from_box(version, doc, 'pdf', 0)

        get_thumbnail(version, doc)
      elsif doc.status == "error"
        Notification.when_doc_upload_finished(version)
        BaseService.notify_or_ignore_error(Exception.new("Document is falied when uploaded: #{version.document.try(:title)} with version #{version.id}"))
      end
    rescue Exception => e
      puts "upload-doc-to-box failed: #{e.message}"
      version.update_attributes({box_status: "error"})
      Notification.when_doc_upload_finished(version)
      BaseService.notify_or_ignore_error(e)
    end
  end

  ##
  # Get converted document from Box-View
  ##
  def self.get_converted_document(version)
    begin
      return if version.blank? || version.file_url.blank? || version.box_view_id.blank? || version.box_status == "done" || version.attemps_num_download_converted_file.to_i > Version::MAX_ATTEMPS_NUM_DOWNLOAD

      doc = BoxView::Models::Document.new(id: version.box_view_id)
      doc.reload

      attemps = 0
      while (doc.status != "done" && doc.status != "error" )
        attemps += 1

        sleep 3
        doc = doc.reload
        puts "version: #{version.id} - attemps: #{attemps} - status: #{doc.status}"

        break if attemps > 10
      end

      version.update_attributes({box_status: doc.status, attemps_num_download_converted_file: version.attemps_num_download_converted_file.to_i + 1})

      if doc.status == "done"
        download_zipfile_from_box(version, doc, 'pdf', 0)

        get_thumbnail(version, doc)
      elsif doc.status == "error"
        BaseService.notify_or_ignore_error(Exception.new("Document is falied when uploaded: #{version.document.try(:title)} with version #{version.id}"))
      end
    rescue Exception => e
      version.update_attributes({box_status: "error"})
      BaseService.notify_or_ignore_error(e)
    end
  end

  ##
  # Download zip file from box and upload it to s3
  # format = zip/pdf
  ##
  def self.download_zipfile_from_box(version, box_doc, format = 'zip', num_call = 0)
    begin
      doc = version.document
      file_name = "tmp/#{version.document_id}-#{version.id}.#{format}"
      file_name_encrypted = "tmp/#{version.document_id}-#{version.id}-encrypted.#{format}"

      f = File.open(file_name, 'w', encoding: 'ASCII-8BIT')
      f.write(box_doc.content(format))
      f.flush
      f.close

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

        #encrypt txt file
        XOREncrypt.encrypt_decrypt(file_txt_name, doc.id.to_s, file_txt_name_encrypted, 4)
        upload_file_to_s3(version, file_txt_name_encrypted, "txt")

        version.text_file_size = File.size(file_txt_name)
      end

      version.box_file_size = File.size(file_name)
      version.save

      #encrypt file
      XOREncrypt.encrypt_decrypt(file_name, doc.try(:company_id).to_s, file_name_encrypted)

      upload_file_to_s3(version, file_name_encrypted, format)
    rescue Exception => e
      if num_call < 3
        download_zipfile_from_box(version, box_doc, format, (num_call + 1)) 
      end
      BaseService.notify_or_ignore_error(e)
    end
  end

  ##
  # After get zip file from Box, upload this file to S3
  ##
  def self.upload_file_to_s3(version, file_name, format = 'zip')
    begin
      doc = version.document
      url = ''

      s3 = AWS::S3.new(access_key_id: CONFIG[:amazon_access_key],
          secret_access_key: CONFIG[:amazon_secret])

      current_bucket = s3.buckets[CONFIG[:bucket]]

      doc_name_parts = { title: doc.title.gsub(' ', '+'), version: "v#{version.code}" }

      name_on_s3 = ["#{doc.company_id}", "documents", "#{doc_name_parts[:title]}", 
        "#{doc_name_parts[:version]}"]


      name_on_s3 << "#{doc_name_parts.values.join('-')}.#{format}"
      obj = current_bucket.objects[name_on_s3.join("/")]

      zip_file = File.open(file_name, 'rb')

      obj.write(zip_file, :acl => :public_read)

      url = obj.public_url(:secure => true).to_s

      File.delete(file_name)

      ##Update url in version
      if format == 'png'
        version.update_attributes({thumbnail_url: url})
      elsif format == 'pdf'
        version.update_attributes({doc_file: url, created_time: Time.now.utc})
      elsif format == 'txt'
        version.update_attributes({text_file: url})
      end

      url
    rescue Exception => e
      BaseService.notify_or_ignore_error(e)
      ""
    end
  end

  ##
  # Get thubnail of a doc's version
  ##
  def self.get_thumbnail(version, box_doc)
    begin
      file_name = "tmp/#{version.document_id}-#{version.id}.png"
      f = File.open(file_name, 'w', encoding: 'ASCII-8BIT')

      attemps = 0

      while attemps < 10
        begin
          f.write(box_doc.thumbnail(1024, 768))
          attemps = 100
        rescue Exception => e
          attemps += 1
        end
      end

      f.flush

      #upload_file_to_s3(version, file_name, 'png')
      version.image = f
      version.save

      f.close
    rescue Exception => e
      BaseService.notify_or_ignore_error(e)
    end
  end
end

# ##
# # Add non_svg parameter when upload documents
# ##
# module BoxView
#   module Api
#     class Document < Base

#       def upload(url, options = {})
#         params = { url: url, name: options[:name], thumbnails: options[:thumbnails], non_svg: options[:non_svg] }.reject!{|key, value| value.blank?}
#         data_item(session.post(endpoint_url, params.to_json), session)
#       end

#     end
#   end
# end