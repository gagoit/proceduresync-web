class ActivityLog
  include Mongoid::Document
  include Mongoid::Timestamps

  # + Created Document "#{doc_title}"
  # + Updated Document "#{doc_title}"
  # + Made Document Inactive "#{doc_title}"
  # + Approved Document "#{doc_title}"
  # + Favourited Document "#{doc_title}"
  # + Updated User #{user_name}
  # + Read Document "#{doc_title}"
  ACTIONS = {
    read_document: "read_document",
    favourite_document: "favourite_document",
    unfavourite_document: "unfavourite_document",
    approved_document: "approved_document",
    unapproved_document: "unapproved_document",
    updated_version: "updated_version",
    created_document: "created_document",
    updated_document: "updated_document",
    made_document_inactive: "made_document_inactive",
    created_user: "updated_user",
    updated_user: "updated_user",
    updated_company: "updated_company",
    created_organisation_structure: "created_organisation_structure",
    updated_organisation_structure: "updated_organisation_structure",
    created_permission: "created_permission",
    updated_permission: "updated_permission",
    updated_report: "updated_report"
  }

  DOC_LOG_TYPES = [
    "read_document", "favourite_document", "unfavourite_document", "approved_document",
    "updated_version", "created_document", "updated_document", "made_document_inactive"
  ]

  USER_LOG_TYPES = [
    "updated_user", "created_user"
  ]

  COMPANY_LOG_TYPES = [
    "updated_company", "created_organisation_structure", "updated_organisation_structure",
        "created_permission", "updated_permission", "updated_report"
  ]

  field :action, type: String
  field :action_time, type: Time

  field :attrs_changes, type: Hash, default: {}

  field :view_document_log, type: String
  field :view_company_log, type: String
  field :view_user_log, type: String

  belongs_to :user, inverse_of: :activity_logs

  belongs_to :company

  belongs_to :target_document, class_name: "Document", inverse_of: :activity_logs 
  belongs_to :target_user, class_name: "User", inverse_of: :target_activity_logs 

  validates_presence_of :action

  # This is template model, each company will have a sparate collection based on this model and named #{company_id}_activity_logs
  # When you add new index here, you must be add this index to all company's collections:
  #   - Need to add seed to update old collections ( just run create_indexes_for_dynamic_collections method for all company )
  #   - Need to add new index to create_indexes_for_dynamic_collections method in Company model

  INDEXES = [
    {user_id: 1},
    {target_document_id: 1},
    {action: 1, user_id: 1},
    {action_time: 1}
  ]

  INDEXES.each do |ind|
    index(ind)
  end

  before_save do
    if action_time.blank?
      self.action_time = Time.now.utc
    end

    if company_id.nil? && target_document_id
      self.company_id = target_document.company_id
    end

    ## Generate log text
    if view_company_log.blank? || view_document_log.blank? || view_user_log.blank?
      begin
        log_result = generate_log_text([:company, :document, :user])
    
        self.view_company_log = log_result[:view_company_log]
        self.view_document_log = log_result[:view_document_log]
        self.view_user_log = log_result[:view_user_log]
      rescue Exception => e
        puts "--------errors when save log: #{e.message}"
      end
    end
  end

  ##
  # Generate log text for each view
  ##
  def generate_log_text(views = [:company, :document, :user])
    views ||= []
    views = ([:company, :document, :user] & views rescue []) 
    result = {}

    views.each do |log_view|
      i_hash, add_text = LogService.get_more_log_info(self, nil, company, log_view.to_s)

      act_text = I18n.t("logs.#{log_view}.#{self.action}", i_hash)
      result[:"view_#{log_view}_log"] = "#{act_text} #{add_text.join(', ')}" if add_text.length > 0
    end

    result
  end

  ##
  # to string
  ##
  def to_string(current_user)
    i_hash = {user_name: "", doc_title: "", version: "", cate_name: ""}
    if target_user_id
      i_hash[:user_name] = target_user.try(:name)

      act_text = I18n.t("logs.user.#{action}", i_hash)
    else
      i_hash[:user_name] = target_document.try(:name)
      i_hash[:user_name] = user.try(:name)
      i_hash[:version] = attrs_changes["version"] || ""

      act_text = I18n.t("logs.document.#{action}", i_hash)
    end

    act_text
  end
end
