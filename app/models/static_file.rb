##
# Modal content the static files:
# - Terms & Conditions
# - Privacy Policy
##
class StaticFile
  include Mongoid::Document
  include Mongoid::Paperclip
  include Mongoid::Timestamps

  WEBSITE_TERMS_OF_USE = "website_terms_of_use"
  TERMS_AND_CONDITIONS = "terms_and_conditions"
  PRIVACY_POLICY = "privacy_policy"

  FILE_NAMES = [TERMS_AND_CONDITIONS, PRIVACY_POLICY, WEBSITE_TERMS_OF_USE]

  field :name, type: String, default: TERMS_AND_CONDITIONS

  has_mongoid_attached_file :file,
                            storage: :s3,
                            s3_permissions: :public_read,
                            s3_credentials: {access_key_id: CONFIG['amazon_access_key'],
                                             secret_access_key: CONFIG['amazon_secret'],
                                             bucket: CONFIG[:bucket]}

  #https://developers.box.com/box-view-faq/
  validates_attachment_content_type :file, :content_type => ["application/pdf","application/vnd.ms-excel", 
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet","application/msword", 
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "application/vnd.ms-powerpoint",
    "application/vnd.openxmlformats-officedocument.presentationml.presentation"]

  field :doc_file, type: String #URL to doc file (pdf)
  field :in_new_box, type: Boolean
  field :box_view_id, type: String #ID of doc in NEW Box View
  field :old_box_view_id, type: String #ID of doc in OLD Box View
  field :box_status, type: String, default: 'processing'
      #(document status in Box) An enum indicating the conversion status of this document.
      #Can be queued, processing, done, or error.

  field :box_file_size, type: Float, default: 0

  field :attemps_num_download_converted_file, type: Integer, default: 0
  
  validates_presence_of :name, :file
  validates_uniqueness_of :name

  index({name: 1})

  after_save :check_and_upload_file

  def check_and_upload_file
    if file_file_name && (file_file_name_changed? || file_content_type_changed? || file_fingerprint_changed? || file_file_size_changed?)
      StaticFile.upload_file(self)
    end
  end

  ##
  #
  ##
  def self.upload_file(s_f)
    return unless s_f && s_f.file_file_name

    result = FileService.upload_to_box(s_f.file.url, "#{s_f.name}-#{s_f.id}-#{s_f.file_updated_at.to_i}")

    StaticFile.skip_callback(:save, :after, :check_and_upload_file)

    s_f.update_attributes(result)

    StaticFile.set_callback(:save, :after, :check_and_upload_file)
  end

  ##
  # Get view and assets url
  # @example:
  #  view url: https://view-api.box.com/1/sessions/8d687fbdc96942d38ca66014175750fd/view?theme=dark
  #  assets url: https://view-api.box.com/1/sessions/8d687fbdc96942d38ca66014175750fd/assets
  ##
  def get_box_url
    return get_new_box_url if in_new_box

    doc = nil

    begin
      view_url = Rails.cache.fetch("/static_files/#{id}-#{box_view_id}-#{updated_at.to_i}/view_url", :expires_in => 50.minutes) do
        doc = BoxView::Models::Document.new(id: box_view_id)
        doc.reload
        doc.document_session({duration: 1101600}).view_url
      end

      if doc
        assets_url = doc.document_session.assets_url
      else
        assets_url = Rails.cache.fetch("/static_files/#{id}-#{box_view_id}-#{updated_at.to_i}/assets_url", :expires_in => 50.minutes) do
          doc = BoxView::Models::Document.new(id: box_view_id)
          doc.reload
          doc.document_session({duration: 1101600}).assets_url
        end
      end
      
    rescue Exception => e
      view_url = assets_url = ""
      BaseService.notify_or_ignore_error(e)
    end

    ## Send email to dev to alert about missing static file
    UserMailer.delay.alert_missing_static_file(name) if view_url.blank? || assets_url.blank?

    return view_url, assets_url
  end

  def get_new_box_url
    return NewBox::GetEmbedUrl.call(box_view_id), nil
  end
end