module Boxr
  class Client

    ##
    # Upload file from url
    ##
    def upload_file_from_url(file_url, parent, name: nil, content_created_at: nil, content_modified_at: nil, preflight_check: true, send_content_md5: true, size: nil)

      parent_id = ensure_id(parent)

      filename = if name
          name
        else
          file_url.split("?").first.split("/").last
        end

      if preflight_check && size
        preflight_check_when_know_size(filename, parent_id, size)
      end

      file_info = nil
      response = nil

      file = open(URI.encode(file_url)) rescue open(file_url)
      content_md5 = send_content_md5 ? Digest::SHA1.file(file).hexdigest : nil

      attributes = {name: filename, parent: {id: parent_id}}
      attributes[:content_created_at] = content_created_at.to_datetime.rfc3339 unless content_created_at.nil?
      attributes[:content_modified_at] = content_modified_at.to_datetime.rfc3339 unless content_modified_at.nil?

      body = {attributes: JSON.dump(attributes), file: file}

      file_info, response = post(FILES_UPLOAD_URI, body, process_body: false, content_md5: content_md5)

      file_info.entries[0]
    end

    ##
    # Get real thumbnail
    # https://developer.box.com/v2.0/reference#get-representations
    ##
    def get_representations(file)
      file_id = ensure_id(file)
      uri = "#{FILES_URI}/#{file_id}"

      body, response = get(uri, query: {fields: "representations"}, success_codes: [302,202,200], process_response: false)

      puts "------representations:"
      puts JSON.parse(body)

      JSON.parse(body)
    end

    ##
    # Get real thumbnail
    # https://developer.box.com/v2.0/reference#get-representations
    # FORMAT: "png"/"jpg"
    ##
    def new_thumbnail(file, thumb_format = "png")
      begin
        representations = get_representations(file)
        representation = representations["representations"]["entries"].select{|e| e["representation"] == thumb_format}.first

        return nil if representation.blank? || representation["info"].blank?

        thumbnail_url = representation["info"]["url"]
        thumbnail_url << "/content/1.#{thumb_format}"
        thumbnail_url.gsub!("https://api.box.com/", "https://dl.boxcloud.com/api/")
        
        puts "---------------"
        puts thumbnail_url

        thumbnail_body, thumbnail_response = get(thumbnail_url, query: {}, success_codes: [302,202,200], process_response: false)
        thumbnail_body
      rescue Exception => e
        puts "Boxr::Client.new_thumbnail Exception: #{e.message}"
        nil
      end
    end


    ##
    # Get real thumbnail
    # https://developer.box.com/v2.0/reference#fetching-a-pdf-representation
    ##
    def download_pdf(file)
      begin
        representations = get_representations(file)
        representation = representations["representations"]["entries"].select{|e| e["representation"] == "pdf"}.first

        return nil if representation.blank? || representation["info"].blank?

        pdf_url = representation["info"]["url"]
        pdf_url << "/content/"
        pdf_url.gsub!("https://api.box.com/", "https://dl.boxcloud.com/api/")

        puts "---------------pdf_url:"
        puts pdf_url

        pdf_body, pdf_response = get(pdf_url, query: {}, success_codes: [302,202,200], process_response: false)
        pdf_body
      rescue Exception => e
        puts "Boxr::Client.download_pdf Exception: #{e.message}"
        nil
      end
    end
  end

  private

  def preflight_check_when_know_size(filename, parent_id, size)
    attributes = {name: filename, parent: {id: "#{parent_id}"}, size: size}
    body_json, res = options("#{FILES_URI}/content", attributes)
  end
end