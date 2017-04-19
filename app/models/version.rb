class Version
  include Mongoid::Document
  include Mongoid::Paperclip
  include Mongoid::Timestamps

  MAX_ATTEMPS_NUM_DOWNLOAD = 3

	has_mongoid_attached_file :file,
                            storage: Rails.env.production? ? :s3 : :filesystem,
                            s3_permissions: :public_read,
                            s3_credentials: {access_key_id: CONFIG['amazon_access_key'],
                                             secret_access_key: CONFIG['amazon_secret'],
                                             bucket: CONFIG[:bucket]}

  #validates_attachment_size :file, :less_than => 2.megabytes
  #https://developers.box.com/box-view-faq/
  validates_attachment_content_type :file, :content_type => ["application/pdf","application/vnd.ms-excel", 
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet","application/msword", 
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "application/vnd.ms-powerpoint",
    "application/vnd.openxmlformats-officedocument.presentationml.presentation"]

  # do_not_validate_attachment_file_type :file

  field :version, type: String

  field :code, type: String #internal version

  field :file_url, type: String #URL to uploaded file
  field :file_name, type: String #name of original file
  field :file_size, type: Float, default: 0 #size of original file

  field :zip_file, type: String #URL to zip file
  field :doc_file, type: String #URL to doc file (pdf)
  field :text_file, type: String #URL to text extraction file (txt)

  field :thumbnail_url, type: String #URL to thumbnail

  has_mongoid_attached_file :image, styles: { thumb: ["70x100#", :jpg] },
                                    convert_options: {all: ["-unsharp 0.3x0.3+5+0", "-quality 90%", "-auto-orient"]},
                                    processors: [:thumbnail] ,
                                    storage: Rails.env.production? ? :s3 : :filesystem,
                                    s3_permissions: :public_read,
                                    s3_credentials: {access_key_id: CONFIG['amazon_access_key'],
                                                     secret_access_key: CONFIG['amazon_secret'],
                                                     bucket: CONFIG[:bucket]}

  validates_attachment_content_type :image, :content_type => %w(image/png image/jpg image/jpeg image/gif)


  field :box_view_id, type: String #ID of doc in Box View

  field :box_status, type: String, default: 'processing'
      #(document status in Box) An enum indicating the conversion status of this document.
      #Can be queued, processing, done, or error.

  field :box_file_size, type: Float, default: 0
  field :text_file_size, type: Float, default: 0

  field :attemps_num_download_converted_file, type: Integer, default: 0

  #created time of version, when this field has been changed, the app should be re-download doc file
  field :created_time, type: Time

  field :need_validate_required_fields, type: Boolean

  # The ability to upload a new file to a document without requiring people to read it again or push any notification.  
  # This would be used to merely correct a mistake in a document file.
  field :document_correction, type: Boolean, default: false

  belongs_to :user

  belongs_to :document

  index({document_id: 1, box_status: 1})
  index({document_id: 1, box_status: 1, created_at: -1})

  validates_presence_of :document_id, :file_url

  #validates :version, presence: true, if: :version_is_required?

  before_validation do
    if file_file_name && file_updated_at_changed?
      self.file_url = file.url
      self.file_size = file_file_size
    end

    if self.new_record? && self.document
      self.code = ((self.document.version_ids || []).length + 1).to_s
    end
  end

  after_save do
    do_not_make_document_unread = document_correction
    Version.where(:id => self.id).update_all(need_validate_required_fields: false)

    if file_url_changed? && file_url
      DocumentService.delay(queue: "notification_and_convert_doc").upload_to_box(self)
    end

    if box_status == "done" && (doc = self.document) && doc.current_version.try(:id) == id

      if doc_file_changed?
        Document.where(:id => doc.id).update_all({
          curr_version_size: (box_file_size || 0),
          curr_version_text_size: (text_file_size || 0),
          cv_doc_file: doc_file,
          cv_text_file: text_file,
          cv_created_time: created_time,
          cv_thumbnail_url: get_thumbnail_url
        })

        Notification.when_doc_upload_finished(self)
        Notification.when_doc_need_approve(doc) if doc.need_approval
        #Notification.when_doc_is_assign(doc, {new_version: true})

        doc.has_changed!({new_version: !do_not_make_document_unread})

        self.document.create_logs({user_id: user_id, action: ActivityLog::ACTIONS[:updated_version], 
          attrs_changes: {"version" => version, "doc_file" => [doc_file_was, doc_file],
          "file_url" => file_url}})

        #If a current document has the file changed or version number changed, 
        #any users should be required to read and accept that document again
        User.remove_invalid_docs("all", [self.document.id], [:read]) if !do_not_make_document_unread

        Version.where(:id => self.id).update_all(document_correction: false) if do_not_make_document_unread
      
      elsif image_fingerprint_changed?
        Document.where(:id => doc.id).update_all({cv_thumbnail_url: get_thumbnail_url})
      elsif text_file_changed?
        Document.where(:id => doc.id).update_all({cv_text_file: text_file})
      end
    end

    if document_id_changed? && (old_doc = Document.where(id: self.document_id_was).first)
      old_doc.has_changed!
    end
  end

  scope :success, -> {where(box_status: 'done')}

  def version_is_required?
    return true if document.nil?
    return false unless need_validate_required_fields

    (document.company.try(:document_settings) || ["version"]).include?("version")
  end

  def get_thumbnail_url
    image_file_name ? image.url(:thumb) : ""
  end

  def get_origin_url
    !file_url.blank? ? file_url : (file_file_name ? file.url: "")
  end

  def get_pdf_url
    #DocumentService.s3_signed_url(doc_file)
    doc_file
  end

  ##
  # Get view and assets url
  # @example:
  #  view url: https://view-api.box.com/1/sessions/8d687fbdc96942d38ca66014175750fd/view?theme=dark
  #  assets url: https://view-api.box.com/1/sessions/8d687fbdc96942d38ca66014175750fd/assets
  ##
  def get_box_url
    doc = nil

    begin
      view_url = Rails.cache.fetch("/documents/#{document_id}/versions/#{id}-#{box_view_id}/view_url", :expires_in => 50.minutes) do
        doc = BoxView::Models::Document.new(id: box_view_id)
        doc.reload
        doc.document_session.view_url
      end

      if doc
        assets_url = doc.document_session.assets_url
      else
        assets_url = Rails.cache.fetch("/documents/#{document_id}/versions/#{id}-#{box_view_id}/assets_url", :expires_in => 50.minutes) do
          doc = BoxView::Models::Document.new(id: box_view_id)
          doc.reload
          doc.document_session.assets_url
        end
      end
      
    rescue Exception => e
      view_url = assets_url = ""
    end

    return view_url, assets_url
  end
end
