class ImportUser
  include Mongoid::Document
  include Mongoid::Paperclip
  include Mongoid::Timestamps

  STATUS = ["processing", "done", "error"]

  belongs_to :company

  has_mongoid_attached_file :file,
                            storage: Rails.env.production? ? :s3 : :filesystem,
                            s3_permissions: :public_read,
                            s3_credentials: {access_key_id: CONFIG['amazon_access_key'],
                                             secret_access_key: CONFIG['amazon_secret'],
                                             bucket: CONFIG[:bucket]}

  #validates_attachment_size :file, :less_than => 2.megabytes
  #https://developers.box.com/box-view-faq/
  validates_attachment_content_type :file, :content_type => ['text/csv','text/comma-separated-values','text/csv','application/csv','application/excel','application/vnd.ms-excel','application/vnd.msexcel','text/anytext','text/plain']

  field :status, type: String, default: "processing"

  # This file has #{line} lines, 
  # {
  #   lines: 
  #   users:
  #   invalid_users:
  #   valid_users:
  #   
	# }
  field :result, type: Hash, default: {}

  def format_result
    html = "<ul>"

    result.each do |key, value|
      html << format_key_value(key, value)
    end

    html << "</ul>"

    html
  end

  def format_key_value(key, value)
    key_text = key.blank? ? '' : (I18n.t("user.import.keys.#{key}") + ':')
    
    if value.is_a?(Hash)
      tmp = "<li>#{key_text} <ul>"
         
      value.each do |k, v|
        tmp << format_key_value(k, v)
      end

      tmp << "</ul> </li>"

    elsif value.is_a?(Array)
      tmp = "<li>#{key_text} <ol>"
         
      value.each do |e|
        e_tmp = e
        if key.to_s == "valid_users"
          e_tmp = {"name" => e["name"], "email" => e["email"]}
        elsif key.to_s == "invalid_users"
          e_tmp = {"name" => e["name"], "email" => e["email"], "result_check" => e["result_check"]}
        end

        tmp << format_key_value(nil, e_tmp)
      end

      tmp << "</ol> </li>"

    else
      tmp = "<li>#{key_text} #{value}</li>"
    end

    tmp
  end
end