require 'httparty'
class BaseService
	include HTTParty

	##
  # After get zip file from Box, upload this file to S3
  ##
  def self.upload_file_to_s3(file_name, options={path_on_s3: [], delete_after_upload: false, public_url: false})
    begin
     	url = ''
      s3 = AWS::S3.new(access_key_id: CONFIG[:amazon_access_key],
          secret_access_key: CONFIG[:amazon_secret])

      current_bucket = s3.buckets[CONFIG[:bucket]]

      name_on_s3 = (options[:path_on_s3] << file_name)
      obj = current_bucket.objects[name_on_s3.join("/")]

      file = File.open(file_name, 'rb')

      obj.write(file)

      File.delete(file_name) if options[:delete_after_upload]

      url = if options[:public_url]
              obj.public_url(:secure => true).to_s
            else
              obj.url_for(:secure => true).to_s
            end

    rescue Exception => e
      BaseService.notify_or_ignore_error(e)
      ""
    end
  end

  def self.s3_signed_url(path, options = {expire_date: nil, force_download: false, content_type: "application/csv"})
    return "" unless path
    
    expire_date = options[:expire_date] || (Time.now.utc + 1.hour).to_i
    
    if path.include?("#{CONFIG[:bucket]}.s3.amazonaws.com/")
      path = path.split("s3.amazonaws.com/").last
    elsif path.include?("s3.amazonaws.com/#{CONFIG[:bucket]}/")
      path = path.split("s3.amazonaws.com/#{CONFIG[:bucket]}/").last
    end

    if path.include?("?")
      path = path.split("?").first
    end

    digest = OpenSSL::Digest::Digest.new('sha1')
    can_string = "GET\n\n\n#{expire_date}\n/#{CONFIG[:bucket]}/#{path}"

    postfix = ""
    if options[:force_download]
      postfix = "response-content-disposition=attachment&response-content-type=#{options[:content_type] || 'application/csv'}"

      can_string = "#{can_string}?#{postfix}"
    end

    hmac = OpenSSL::HMAC.digest(digest, CONFIG[:amazon_secret], can_string)
    signature = URI.escape(Base64.encode64(hmac).strip).encode_signs

    signed_url = "https://#{CONFIG[:bucket]}.s3.amazonaws.com/#{path}?AWSAccessKeyId=#{CONFIG[:amazon_access_key]}&Expires=#{expire_date}&Signature=#{signature}"
    
    signed_url = "#{signed_url}&#{postfix}" if options[:force_download]
    
    signed_url
  end

	def self.time_formated(company, time, format = I18n.t("datetime.format") )
    if time
      time.in_time_zone(company.timezone).strftime(format) rescue ""
    else
      ""
    end
  end

  ##
  # Convert string to time in current timezone
  # I18n.t("datetime.format")
  ##
  def self.convert_string_to_time(company, str, format = I18n.t("datetime.format"))
    pacific_time_zone = ActiveSupport::TimeZone.new(company.timezone)
    
    pacific_time_zone.strptime(str, format).utc rescue nil
  end

  ##
  # Notify when have error
  ##
  def self.notify_or_ignore_error(exception)
    if defined?(Airbrake) && Rails.env.production?
      Airbrake.notify_or_ignore(exception)
    else
      puts exception.message
    end
  end

  ##
  # Get area's name
  ##
  def self.area_name(company, path_id, all_paths_hash = nil)
    return nil unless path_id.include?(Company::NODE_SEPARATOR)

    all_paths_hash ||= company.all_paths_hash

    return all_paths_hash[path_id] if all_paths_hash[path_id]

    return nil unless (new_path = company.company_structures.where(path: /#{path_id}/).order([:created_at, :desc]).first)

    return nil unless (new_name = all_paths_hash[new_path.path])

    new_name.split(Company::NODE_SEPARATOR)[0..(path_id.split(Company::NODE_SEPARATOR).length-2)].join(Company::NODE_SEPARATOR) rescue nil
  end

  def self.yes_no_text(condition)
    condition ? "Yes" : "No"
  end

  def self.get_first_line_num_in_exception(exception)
    exception.backtrace.map{ |x|   
      x.match(/^(.+?):(\d+)(|:in `(.+)')$/); 
      [$1,$2,$4].join(":") 
    }.first
  end
end