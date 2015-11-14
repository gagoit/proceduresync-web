class FileService < BaseService
  
  ##
  # Upload file to Box-View
  # 
  ##
  def self.upload_to_box(file_url, file_name)
    begin
      return if file_url.blank? || file_name.blank?

      result = {
        box_status: "error",
        box_view_id: "",
        doc_file: "",
        box_file_size: 0
      }

      doc = BoxView::Api::Document.new.upload(file_url, file_name)

      attemps = 0
      while (doc.status != "done" && doc.status != "error" )
        attemps += 1

        sleep 3
        doc = doc.reload
        puts "#{file_name} - #{file_url} - attemps: #{attemps} - status: #{doc.status}"

        break if attemps > 100
      end

      result[:box_status] = doc.status
      result[:box_view_id] = doc.id

      if doc.status == "done"
        doc_file_hash = download_zipfile_from_box(file_name, doc, 'pdf', 0)
        result.merge!(doc_file_hash)

      elsif doc.status == "error"
        BaseService.notify_or_ignore_error(Exception.new("File uploaded falied: #{file_name} #{file_url}"))
      end
    rescue Exception => e
      puts "upload-doc-to-box failed: #{e.message}"
      BaseService.notify_or_ignore_error(e)
    end

    result
  end

  ##
  # Download zip file from box and upload it to s3
  # format = zip/pdf
  ##
  def self.download_zipfile_from_box(file_name, box_doc, format = 'zip', num_call = 0)
    result = {
      doc_file: "",
      box_file_size: 0
    }

    begin
      file_name_with_format = "#{file_name}.#{format}"
      file_name_with_format_path = "tmp/#{file_name_with_format}"

      f = File.open(file_name_with_format_path, 'w', encoding: 'ASCII-8BIT')
      f.write(box_doc.content(format))
      f.flush
      f.close

      result[:box_file_size] = File.size(file_name_with_format_path)

      name_on_s3 = ["static_files", "#{file_name_with_format}"]

      result[:doc_file] = upload_file_to_s3(file_name_with_format_path, {path_on_s3: name_on_s3, delete_after_upload: true, public_url: true})
    
    rescue Exception => e
      if num_call < 3
        download_zipfile_from_box(file_name, box_doc, format, (num_call + 1)) 
      end
      BaseService.notify_or_ignore_error(e)
    end

    result
  end

end