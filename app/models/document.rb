require 'csv'
class Document
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Search

  #I18n.t("document.assign_for")
  # If document is assigned for restricted, it's not accountable, it just shows in restricted areas
  ASSIGN_FOR = {
    accountable: "accountable",
    approval: "approval",
    restricted: "restricted"
  }

  search_in :title, :doc_id, :created_time, :expiry, :category_name, :curr_version

  field :title, type: String

  field :doc_id, type: String

  field :expiry, type: Time

  field :created_time, type: Time
  field :effective_time, type: Time

  field :inactive, type: Boolean, default: false
  field :active, type: Boolean, default: true

  field :effective, type: Boolean, default: true

  field :restricted, type: Boolean, default: false
  
  #When user Add/Edit document: When they click Restricted, there will be one more option in the Assign Document / Action: 
  #"Restrict to these Areas"
  field :restricted_paths, type: Array, default: []

  field :is_private, type: Boolean, default: false

  field :belongs_to_paths, type: Array, default: []
  field :need_approval, type: Boolean, default: false

  # belongs_to :approved_by, class_name: "User", inverse_of: :approved_documents
  # field :approved_at, type: Time
  field :approved, type: Boolean, default: false

  # The parts of organisation that document is approved for
  # It will be equal belongs_to_paths if this document doesn't need to be approved
  field :approved_paths, type: Array, default: []
  has_and_belongs_to_many :approved_bys, class_name: "User", inverse_of: :approved_documents
  has_many :approver_documents

  # The parts of organisation that document is not approved for
  # It will be equal [] if this document doesn't need to be approved
  # and approved_paths + not_approved_paths + not_accountable_for = belongs_to_paths
  field :not_approved_paths, type: Array, default: []

  # The parts of organisation that document has been set as not accountable by an approver
  # It will be equal [] if this document doesn't need to be approved
  # and approved_paths & not_accountable_for = []
  # and not_accountable_for is small set of belongs_to_paths
  field :not_accountable_for, type: Array, default: []
  field :not_accountable_by_ids, type: Array, default: []

  # The last time that document has been set as not accountable by an approver
  field :time_set_as_not_accountable, type: Time
  field :process_approval_expiration, type: Boolean, default: false

  has_many :versions, order: [:created_at, :desc]

  field :category_name, type: String

  ## Current version info:
  field :curr_version, type: String
  field :curr_version_size, type: Float, default: 0 # box_file_size
  field :curr_version_text_size, type: Float, default: 0 # text_file_size

  field :cv_doc_file, type: String
  field :cv_text_file, type: String
  field :cv_created_time, type: Time
  field :cv_thumbnail_url, type: String

  field :assign_document_for, type: String

  field :need_validate_required_fields, type: Boolean

  # The ability to upload a new file to a document without requiring people to read it again or push any notification.  
  # This would be used to merely correct a mistake in a document file.
  field :document_correction, type: Boolean, default: false

  has_and_belongs_to_many :favourited_users, class_name: "User", inverse_of: :favourite_documents

  has_and_belongs_to_many :read_users, class_name: "User", inverse_of: :read_documents

  belongs_to :category
  belongs_to :company

  has_many :activity_logs, class_name: "ActivityLog", inverse_of: :target_document 

  belongs_to :created_by, class_name: "User", inverse_of: :created_documents
  belongs_to :updated_by, class_name: "User", inverse_of: :updated_documents
  belongs_to :private_for, class_name: "User", inverse_of: :private_documents

  has_many :user_documents

  has_one :document_content

  validates_presence_of :title, :company_id, :created_time

  validates_uniqueness_of :title, scope: :company_id

  validates_presence_of :doc_id, if: :doc_id_is_required?
  validates_presence_of :expiry, if: :expiry_is_required?
  validates_presence_of :curr_version, if: :version_is_required?

  validates_presence_of :private_for_id, if: Proc.new { |doc| doc.is_private }
  validates_presence_of :category_id, if: Proc.new { |doc| !doc.is_private }

  index({title: 1, doc_id: 1})

  index({expiry: 1, active: 1})

  index({belongs_to_paths: 1})
  index({approved_paths: 1})
  index({not_approved_paths: 1})
  index({created_at: -1})
  index({private_for_id: 1})

  scope :active, -> {where({active: true})}
  scope :inactive, -> {where({active: false})}
  scope :public_all, -> {where(is_private: false)}
  scope :public_with, ->(current_user) {any_of({is_private: false}, {is_private: true, private_for_id: current_user.id})}
  scope :public_with_in_company, ->(current_user, current_company) { where(company_id: current_company.id).any_of({is_private: false}, {is_private: true, private_for_id: current_user.id})}
  scope :private_with, ->(current_user) {where(is_private: true, private_for_id: current_user.id)}
  scope :has_success_version, -> {where(:'versions.box_status' => 'done')}
  scope :effective, -> {where(:effective_time.lte => Time.now.utc)}
  scope :not_restrict_viewing, -> {where(:assign_document_for.ne => ASSIGN_FOR[:restricted])}

  after_create do
    #Create log
    self.create_logs({user_id: created_by.try(:id), action: ActivityLog::ACTIONS[:created_document], attrs_changes: self.changes})
    
    d_content = DocumentContent.find_or_initialize_by({document_id: self.id})
    d_content.title = title
    d_content.doc_id = doc_id
    d_content.company_id = company_id
    d_content.pages = []
    d_content._keywords = _keywords
    d_content.save
  end

  before_validation do
    self.title = title.to_s.strip
    self.doc_id = doc_id.to_s.strip

    current_time = Time.now.utc

    if private_for_id
      self.is_private = true

      self.created_time = current_time if self.created_time.nil?
      self.expiry = current_time.advance({years: 1000}) if self.expiry.nil?
      self.effective_time = current_time if self.effective_time.nil?
      self.effective = true

      self.approved = true
      self.need_approval = false
      self.belongs_to_paths = []
      self.approved_paths = self.belongs_to_paths
    end

    # if belongs_to_paths.blank? && !is_private
    #   self.errors.add(:base, "Document must be assigned to an area in the organisation")
    #   false
    # end
  end

  before_save do
    current_time = Time.now.utc
    
    if private_for_id
      self.is_private = true
      self.belongs_to_paths = []
    end

    #set inactive when expiry
    if expiry && ((expiry.utc <= current_time) rescue true)
      self.active = false
    end

    #Set effective
    if effective_time && ((effective_time.utc <= current_time) rescue false)
      self.effective = true
    elsif !is_private
      self.effective = false
    end

    if category_id_changed?
      self.category_name = category.try(:name)
    end

    if company 
      self.need_approval = (company.is_advanced? || (company.is_hybrid? && self.assign_document_for == ASSIGN_FOR[:approval]))
      
      #Change from accountable => approval
      if company.is_hybrid? && self.assign_document_for_changed? && self.assign_document_for == ASSIGN_FOR[:approval]
        self.approved = false
        self.approved_paths = []

        #TO-DO: Destroy approver_document
      end
    end

    if !need_approval || !approved_by_ids.blank?
      self.approved = true
    end

    # Check and set approved_paths / not_approved_paths / not_accountable_for paths
    self.correct_paths

    true
  end

  after_save do
    do_not_make_document_unread = document_correction
    Document.where(:id => self.id).update_all(need_validate_required_fields: false, document_correction: false) if need_validate_required_fields

    if self.created_at != self.updated_at
      [:category_id, :title, :doc_id, :created_time, :expiry, :effective_time, :restricted, :active, 
        :belongs_to_paths, :curr_version].each do |f|
        
        if self.send(:"#{f}_changed?")
          field_changes = self.changes
          
          ## When document is approved, we just need to log where it is approved for in approver_document
          field_changes.delete("approved_paths") if approved_by_ids_changed?

          self.create_logs({user_id: updated_by_id, action: ActivityLog::ACTIONS[:updated_document], 
            attrs_changes: field_changes})
          
          ## Update DocumentContent
          d_content = DocumentContent.find_or_initialize_by(document_id: self.id)
          d_content.title = title
          d_content.doc_id = doc_id
          d_content.company = company_id
          d_content._keywords = _keywords
          d_content.save(validate: false)

          break
        end
      end
    end

    #If a current document has the file changed or version number changed, 
    #any users should be required to read and accept that document again
    if self.curr_version_changed? && !do_not_make_document_unread
      User.delay(run_at: (Time.now.utc.advance(seconds: 10))).remove_invalid_docs("all", [self.id], [:read])
    end

    #With private doc, mark it as read for user
    if is_private && private_for && !private_for.read_document_ids.include?(self.id)
      private_for.read_document_ids << self.id
      private_for.save(validate: false)
    end

    has_sent_noti = false

    #only set when document is effective
    if self.current_version && effective
      if is_private_changed?
        NotificationService.delay(queue: "notification_and_convert_doc").document_has_changed_privacy(self)
      end

      #Create notification in Web admin
      #Noti when doc is approved or is assigned
      if active && !is_private
        if need_approval && not_approved_paths_changed? && !not_approved_paths.blank? 
          Notification.delay.when_doc_need_approve(self)
        end

        #If the same document is approved by 2 different approvers for the same section, 
        #make sure only the first notification goes out
        # if ((need_approval && approved_by_ids_changed?) || !need_approval) && approved_paths_changed? && !approved_paths.blank?
        #   Notification.when_doc_is_assign(self, {changed_paths: true, old_paths: approved_paths_was, new_paths: approved_paths})
        # end
      end

      #Check & Set accountable relationship between user and document, and push notification if need
      self.has_changed!({new_version: ((self.curr_version_changed? || (active && active_changed?) || effective_changed?) && !do_not_make_document_unread), 
        change_area: self.approved_paths_changed?})

      has_sent_noti = true
    end

    if (!effective && effective_changed?) || (!active && active_changed?)
      self.has_changed!({}) unless has_sent_noti
    end

    #Add job to check expiry date
    if expiry && active
      Document.delay(run_at: (expiry.utc.advance(minutes: 1))).check_invalid_documents([self.id]) rescue nil
    end
  end

  def doc_id_is_required?
    return true if company.nil?
    return false unless need_validate_required_fields

    (company.try(:document_settings) || ["doc_id"]).include?("doc_id")
  end

  def expiry_is_required?
    return true if company.nil?
    return false unless need_validate_required_fields

    (company.try(:document_settings) || ["expiry"]).include?("expiry")
  end

  def version_is_required?
    return true if company.nil?
    return false unless need_validate_required_fields

    (company.try(:document_settings) || ["version"]).include?("version")
  end

  ##
  # Get same doc with current doc: same title and same doc_id (if company required this field)
  ##
  def same_doc(comp = nil)
    return nil if comp && comp.id != self.company_id
    comp = company if comp.nil?

    if comp.document_settings.include?("doc_id")
      exist_doc = comp.documents.where(:_id.ne => self.id).any_of({title: self.title}, {doc_id: self.doc_id}).first
    else
      exist_doc = comp.documents.where(:_id.ne => self.id, title: self.title).first
    end

    exist_doc
  end

  def destroy
    self.active = false
    self.save(validate: false)
  end

  ##
  # Check document has been approved by user or not
  ##
  def approved_by?(current_user)
    if current_user.is_a?(BSON::ObjectId)
      approved_by_ids.include?(current_user)
    else
      approved_by_ids.include?(current_user.try(:id)) rescue false
    end
  end

  ##
  # Check document can approve by user or not
  ##
  def can_approve_by?(current_user, u_comp = nil)
    u_comp ||= current_user.user_company(company, true)

    need_approval && u_comp["is_approver"] && (
        ( (u_comp["approver_path_ids"] & not_approved_paths).length > 0 && !approved_by?(current_user) ) ||
        ( !(not_accountable_by_ids || []).include?(current_user.try(:id)) && (u_comp["approver_path_ids"] & (not_accountable_for || [])).length > 0 && 
            time_set_as_not_accountable && time_set_as_not_accountable.utc >= Document.approval_expiration_time )
      )
  end

  ##
  # Approver approve document
  ##
  def approve!(current_user, current_company, permit_params, params)
    if !can_approve_by?(current_user)
      result = { success: false,  message: I18n.t("document.approve.error.already_approved")}
    else
      doc_params = permit_params
      if PermissionService.can_add_edit_document(current_user, current_company)
        doc_params[:created_time] = BaseService.convert_string_to_time(current_company, params[:document][:created_time]) unless params[:document][:created_time].blank?
        doc_params[:expiry] = BaseService.convert_string_to_time(current_company, params[:document][:expiry]) unless params[:document][:expiry].blank?
        doc_params[:effective_time] = BaseService.convert_string_to_time(current_company, params[:document][:effective_time]) unless params[:document][:effective_time].blank?
        doc_params[:curr_version] = params[:document][:curr_version]
        doc_params[:updated_by_id] = current_user.id
      else
        doc_params = {title: self.title, doc_id: self.doc_id}
      end

      can_approved_for = ((current_user.user_company(current_company, true)["approver_path_ids"] || []) rescue []) & self.belongs_to_paths
      new_approved_areas = new_not_approved_areas = []

      if params[:document][:approve_document_to] == "approve_selected_areas"
        new_approved_areas = ActiveSupport::JSON.decode(params[:document][:belongs_to_paths])
        new_approved_areas = (can_approved_for & new_approved_areas) - self.approved_paths

        doc_params[:approved_paths] = self.approved_paths + new_approved_areas

      elsif params[:document][:approve_document_to] == "approve_all" #(all areas that approver can approve for)
        new_approved_areas = can_approved_for - self.approved_paths

        doc_params[:approved_paths] = self.approved_paths + new_approved_areas

      else #not_approve
        #in case Approver marks a document as "Not Accountable", we will remove accountability from the areas that approver can approve
        new_not_approved_areas = can_approved_for

        doc_params[:approved_paths] = self.approved_paths - new_not_approved_areas
        doc_params[:not_accountable_for] = ((self.not_accountable_for || []) + new_not_approved_areas).uniq
        doc_params[:time_set_as_not_accountable] = Time.now.utc
        doc_params[:process_approval_expiration] = false
        doc_params[:not_accountable_by_ids] = ((self.not_accountable_by_ids || []) + [current_user.id]).uniq
      end

      doc_params[:approved_paths].uniq!
      doc_params[:approved_by_ids] = self.approved_by_ids.concat([current_user.id])

      doc_params[:approved] = true

      result = { success: true,  message: I18n.t("document.approve.success")}
      result[:version_changed] = (self.curr_version != params[:document][:curr_version])

      if self.update_attributes(doc_params)
        #Create approver_document object
        approver_doc = self.approver_documents.find_or_initialize_by({user_id: current_user.id})
        approver_doc.approve_document_to = params[:document][:approve_document_to]
        approver_doc.approved_paths = new_approved_areas
        approver_doc.not_approved_paths = new_not_approved_areas
        approver_doc.params = params

        approver_doc.save

        if result[:version_changed]
          versions.where(id: current_version.try(:id)).update_all({version: params[:document][:curr_version]})
        end
      else
        result[:success] = false
        result[:message] = self.errors.full_messages.first
      end

      result
    end
  end

  ##
  # Get the current version of the document, it's the lastest version that upload and convert successfully
  ##
  def current_version
    versions.success.order([:created_at, :desc]).first
  end

  def is_expiried
    ((expiry && expiry.utc <= Time.now.utc) || !active)
  end

  def is_inactive
    ((expiry && expiry.utc <= Time.now.utc) || !active)
  end

  ##
  # Document is restrict viewing (is not read receipt accountable) when:
  #  assign_document_for != ASSIGN_FOR[:restricted]
  ##
  def is_not_restrict_viewing
    assign_document_for != ASSIGN_FOR[:restricted]
  end

  ##
  # Document has been changed, need to update the accountable relationship between user and document
  # based on what document has been changed, we will decide to push notification
  # @params:
  #  - options: is a Hash
  #     + new_version:
  #     + update_category:
  #     + update_meta_data: 
  #     + change_area
  ##
  def has_changed!(options = {})
    options[:document] = self
    options[:company] = company

    UserService.delay(queue: "update_data").update_user_documents(options)
  end

  def correct_paths
    #set approved paths for documents that don't need approval
    if !need_approval
      self.approved_paths = self.belongs_to_paths
    end

    self.approved_paths ||= []
    self.belongs_to_paths ||= []
    self.not_accountable_for ||= []

    #check and remove invalid approved paths (that belongs to paths not include)
    self.approved_paths = (self.approved_paths & self.belongs_to_paths)
    self.not_approved_paths = self.belongs_to_paths - self.approved_paths

    self.not_accountable_for = (self.not_accountable_for & self.belongs_to_paths)
    self.not_accountable_for -= self.approved_paths

    self.not_approved_paths -= self.not_accountable_for
  end

  ##
  # Format JSON of a document
  ##
  def to_json(current_user, curr_ver = nil, options = {} )
    # curr_ver ||= self.current_version

    result = {
      uid: self.id.to_s,
      id: self.doc_id,
      title: self.title,
      expiry: self.expiry.try(:utc).to_s,
      created_at: self.created_at.utc.to_s,
      updated_at: self.updated_at.utc.to_s,
      version: self.curr_version,
      doc_file: self.cv_doc_file,
      thumbnail_url: self.cv_thumbnail_url,
      text_file: self.cv_text_file,
      text_size: self.curr_version_text_size,
      is_inactive: self.is_inactive,
      is_favourite: current_user.favourited_doc?(self),
      category: self.category_name.to_s,
      category_id: self.category_id.to_s,
      is_private: (self.private_for_id == current_user.id),
      doc_size: self.curr_version_size,
      version_created_at: (self.cv_created_time.utc.to_s rescue Time.now.utc.to_s)
    }

    if options[:show_is_unread]
      result[:is_unread] = !(current_user.read_doc?(self))
      comp = options[:company] || company
      
      if result[:is_unread] && !current_user.is_required_to_read_doc?(comp, self)
        result[:is_unread] = false
      end
    end

    result
  end

  ##
  # Format JSON of muilti documents 
  ##
  def self.to_json(current_user, coll = [], options = {})
    result = {}
    coll.each do |document|
      document = Document.get_document(document)

      next unless document
      
      # curr_ver = document.current_version
      # next unless curr_ver && !curr_ver.doc_file.blank?
      next if document.cv_doc_file.blank?

      result[document.id] = document.to_json(current_user, nil, options)
    end

    #in case: the document is not available for user, 
    #it should be mark as inactive when sync, and need to be removed from the app
    if docs_need_remove_in_app = options[:docs_need_remove_in_app]
      docs_need_remove_in_app.each do |e|
        result[e.id] ||= e.to_json(current_user, nil, options)
        result[e.id][:is_inactive] = true
      end
    end

    result.values
  end

  ##
  # Sent notify for testing
  ##
  def notify
    NotificationService.delay(queue: "notification_and_convert_doc").document_is_created(self)
  end

  ##
  # Check and set document active or not
  ##
  def self.check_invalid_documents(ids = nil)
    invalid_doc_ids = []
    has_invalid_doc = false
    current_time = Time.now.utc

    query = {active: true}
    if ids
      query.merge!({:id.in => ids})
    end

    Document.where(query).each do |doc|
      if doc.expiry && doc.expiry.utc <= current_time
        invalid_doc_ids << doc.id
        has_invalid_doc = true

        doc.company_users(doc.company).update_all({updated_at: Time.now.utc})
      end
    end

    if has_invalid_doc
      invalid_docs = Document.where(:id.in => invalid_doc_ids)

      invalid_docs.update_all(active: false)

      NotificationService.delay(queue: "notification_and_convert_doc").documents_are_invalid(invalid_docs)
      User.remove_invalid_docs("all", invalid_doc_ids)
    end
  end

  ##
  # Check effective document
  ##
  def self.check_effective_documents(ids = nil)
    query = {effective: false, :effective_time.lte => Time.now.utc }
    if ids
      query.merge!({:id.in => ids})
    end

    Document.where(query).each do |doc|
      doc.effective = true
      doc.save(validate: false)
    end
  end

  ##
  # Get users' id that this doc is accountable
  ##
  def available_for_user_ids(options = {accept_inactive: false})
    return [] if company.nil? 
    return [] if !options[:accept_inactive] && (!active || (expiry && expiry.utc <= Time.now.utc))

    if is_private
      [private_for_id]

    # elsif need_approval
    #   #Just approvers
    #   u_ids = company.user_companies.where(:approver_path_ids.in => not_approved_paths, :user_id.nin => approved_by_ids).pluck(:user_id)
    else
      #
      u_ids = company.user_companies.where(:company_path_ids.in => approved_paths).pluck(:user_id)
    end
  end

  ##
  # Get accountable documents for a area
  ##
  def self.accountable_documents_for_area(comp, path_id)
    query = {:approved_paths => /^#{path_id}/i}

    comp.documents.active.public_all.effective.not_restrict_viewing.where(query)
  end

  # filter may be on of values("favourite", "unread", "private")
  # options: {
  #   page: , 
  #   per_page: , 
  #   search: , 
  #   sort_by = [[:title, :asc]], 
  #   filter = "all", 
  #   category_id = nil,
  #   types: "all"/"accountable"/"not_accountable",
  #   ids: "all"
  # }
  def self.get_all(user, company, options = {page: 1, per_page: OBJECT_PER_PAGE[:document], search: "", sort_by: [[:title, :asc]], filter: "all", category_id: nil, types: "all", order_by_ranking: "false", ids: "all"})
    search = options[:search].to_s.downcase.strip
    types = options[:types].blank? ? "all" : options[:types]
    ids = options[:ids].blank? ? "all" : options[:ids]

    documents = user.docs(company, options[:filter], options[:sort_by], types, need_return_unread_number: false)[:docs]
    
    documents = documents.where(:category_id => options[:category_id]) unless options[:category_id].blank?

    total_count = nil
    if search.blank?
      documents = documents.where(:id.in => ids) if ids != "all"
      
    elsif options[:order_by_ranking] == "true"
      documents = documents.where(:id.in => ids) if ids != "all"
      filter_doc_ids = documents.pluck(:id)
      documents, total_count = DocumentContent.mongo_search(filter_doc_ids, search, options[:page], options[:per_page])
      
    else
      searched_docs = DocumentContent.search(company.id, search)
      searched_docs = searched_docs.where(:document_id.in => ids) if ids != "all"
      searched_doc_ids = searched_docs.pluck(:document_id)

      documents = documents.where(:id.in => searched_doc_ids)
    end
    
    if options[:page] && (search.blank? || !options[:order_by_ranking] == "true")
      documents = documents.page(options[:page]).per(options[:per_page])
      total_count = documents.total_count
    end

    return documents, total_count
  end

  ##
  # Format Documents for Datatable
  ##
  def self.documents_for_datatable(user, company, documents, total_count = nil, filter = "all")
    total_count = (total_count || (documents.total_count rescue documents.length))
    return_data = {
      "aaData" => [],
      "iTotalDisplayRecords" => total_count,
      "iTotalRecords" => total_count
    }

    u_comp = user.user_company(company, true)
    can_add_edit_doc = PermissionService.has_permission(:update, user, company, company.documents.new)

    documents.each do |document|
      document = Document.get_document(document)

      next unless document

      data = {
        title: document.title,
        doc_id: document.doc_id,
        curr_version: document.curr_version,
        created_time: BaseService.time_formated(company, document.created_time),
        expiry: (document.is_private ? "" : BaseService.time_formated(company, document.expiry)),
        restricted: document.restricted,
        category: document.category_name,
        is_private: document.is_private,
        id: document.id.to_s,
        doc_url: Rails.application.routes.url_helpers.document_path(document),
        doc_version_url: ActionController::Base.helpers.link_to(document.title, (Rails.application.routes.url_helpers.document_version_path(document, document.current_version) rescue "")),
        to_approve_url: Rails.application.routes.url_helpers.to_approve_document_path(document),
        approved: document.approved,
        show_edit_btn: can_add_edit_doc
      }

      if !company.is_standard? && u_comp["is_approver"] && (
          ((u_comp["approver_path_ids"] & document.not_approved_paths).length > 0 && !document.approved_by?(user)) ||
          ( filter == "to_approve" && (u_comp["approver_path_ids"] & (document.not_accountable_for || [])).length > 0 && 
              document.time_set_as_not_accountable && document.time_set_as_not_accountable.utc >= Document.approval_expiration_time )
        )
        
        data[:show_approve_btn] = true
        data[:doc_version_url] = ActionController::Base.helpers.link_to(document.title, data[:to_approve_url])
      end

      unless document.current_version
        data[:doc_version_url] = "<i class='fa fa-exclamation-circle' title='Document is still converting' data-placement='bottom' data-toggle= 'tooltip'></i> " + document.title
      end

      if !can_add_edit_doc && document.is_inactive
        document.active = false
        document.save(validate: false)
      else
        return_data["aaData"] << data
      end
    end

    return_data
  end

  # filter may be on of values("favourite", "unread")
  # params:
  #    filter = "all", search = '', sort_by = [[:title, :asc]], ids= "all"
  def self.export_csv(user, company, params)
    filter = params[:filter] || "all"
    search = params[:search].to_s.strip
    ids = params[:ids] || "all"
    types = params[:document_types] || "all"
    filter_category_id = params[:filter_category_id]

    documents, total_count = get_all(user, company, {page: nil, per_page: nil, search: search, sort_by: params[:sort_by], 
        filter: filter, category_id: filter_category_id, types: types, ids: ids, order_by_ranking: params[:order_by_ranking]})

    file = CSV.generate({:write_headers => true}) do |csv|
      csv << ["Name", "ID", "Version", "Created", "Expires", "Restrict", "Category"] ## Header values of CSV
      documents.each do |document|
        document = Document.get_document(document)

        csv << [
          document.title,
          document.doc_id,
          document.curr_version,
          BaseService.time_formated(company, document.created_time),
          BaseService.time_formated(company, document.expiry),
          document.restricted,
          document.category_name
        ]
      end
    end

    return_data = {
      file: file,
      name: "Documents.csv"
    }

    return_data[:name] = "#{filter.titleize} Documents.csv"
    
    return_data[:name] = "Selected #{return_data[:name].gsub('All ', '')}" if ids != "all"

    return return_data
  end

  def self.check_and_download_not_done_documents
    Document.where(active: true, :'versions.box_status'.ne => "done").each do |doc|
      if (v_last = doc.versions.first) && v_last.box_status != "done" && v_last.attemps_num_download_converted_file.to_i <= Version::MAX_ATTEMPS_NUM_DOWNLOAD
        DocumentService.delay(queue: "notification_and_convert_doc").get_converted_document(v_last)
      end
    end
  end

  ##
  # Update category for documents
  # search, filter, ids, params[:category_id]
  ##
  def self.update_category(user, company, params)
    filter = params[:filter] || "all"
    search = params[:search] || ''
    ids = params[:ids] || "all"
    new_category_id = params[:new_category_id]
    types = params[:document_types] || "all"
    filter_category_id = params[:filter_category_id]

    category = Category.find(new_category_id) rescue nil
    result = {success: true, message: "Documents have been updated with new category successfully", num_of_docs: 0}
    
    if !category
      result[:success] = false
      result[:message] = new_category_id.blank? ? "Category can't be blank" : "Category does not exist."
    else
      documents, total_count = get_all(user, company, {page: nil, per_page: nil, search: search, sort_by: [[:title, :asc]], 
        filter: filter, category_id: filter_category_id, types: types, ids: ids, order_by_ranking: params[:order_by_ranking]})

      documents.each do |doc|
        doc = Document.get_document(doc)
        doc.update_attributes({category_id: category.id, category_name: category.name, updated_by_id: user.id})
        result[:num_of_docs] += 1
      end

      if result[:num_of_docs] > 0
        result[:message] = "Document(s) has/have been updated with new category successfully" 
      else
        result[:success] = false
        result[:message] = "No document has been updated"
      end
    end

    result
  end

  # Documents Assignment in documents page
  # Here you can bulk assign many documents to a different part of the organisation:
  # @params:
  # ids: id1,id2,id3
  # assignment_type: {String}
  #  - assign_without_approval: "Distribute document(s) without approval to the following areas"
  #  - add_accountability: "Make document(s) accountable document(s) for the following users"
  #  - remove_accountability: "Make document(s) NOT accountable document(s) for the following users"
  # paths: {Array}
  def self.update_paths(user, company, params)
    result = {success: true, message: "Documents have been updated successfully"}
    new_attrs = {updated_by_id: user.id}

    paths = ActiveSupport::JSON.decode(params[:paths])
    ids = params[:ids] || "all"

    documents, total_count = get_all(user, company, {page: nil, per_page: nil, search: (params[:search] || ''), sort_by: [[:title, :asc]], 
        filter: (params[:filter] || "all"), category_id: params[:filter_category_id], types: (params[:document_types] || "all"), ids: ids, order_by_ranking: params[:order_by_ranking]})

    #auth paths: only accept paths that user have permission
    if !PermissionService.can_add_edit_document(user, company)
      if PermissionService.can_bulk_assign_documents(user, company)
        paths = PermissionService.available_areas_for_bulk_assign_documents(user, company) & paths
      else
        return {success: false, message: I18n.t("error.access_denied")}
      end
    end

    case params[:assignment_type]
    when "assign_without_approval"
      new_attrs[:need_approval] = false
      new_attrs[:approved] = true
      new_attrs[:assign_document_for] = ASSIGN_FOR[:accountable]

      documents.each do |doc|
        doc = Document.get_document(doc)
        next if doc.nil? || doc.is_private

        new_attrs[:belongs_to_paths] = ((doc.belongs_to_paths || []) + paths).uniq
        doc.attributes = new_attrs
        # doc.save(validate: false)

        doc.correct_paths
        Document.where(:id => doc.id).update_all(need_approval: false, approved: true, assign_document_for: ASSIGN_FOR[:accountable],
              belongs_to_paths: doc.belongs_to_paths, approved_paths: doc.approved_paths, 
              not_approved_paths: doc.not_approved_paths, not_accountable_for: doc.not_accountable_for, updated_by_id: user.id)
        doc.create_logs({ user_id: user.id, action: ActivityLog::ACTIONS[:updated_document], 
              attrs_changes: doc.changes })

        # Update UserDocument relationship for syncing
        DocumentService.delay(queue: "update_data").add_accountable_to_paths(company, doc, doc.belongs_to_paths)
      end
    when "add_accountability"
      # Document is already accountable and/or Accountable but not approved: Do nothing.
      # Document is not accountable. Make accountable.
      # - with document need approval, when we add accountability to document, they will be accountable for users in added areas ( don't need to be approve )
      
      user_ids_in_paths = company.user_companies.where(:company_path_ids.in => paths).pluck(:user_id)

      documents.each do |doc|
        doc = Document.get_document(doc)
        next if doc.nil? || doc.is_private

        new_attrs[:belongs_to_paths] = ((doc.belongs_to_paths || []) + paths).uniq
        new_attrs[:approved_paths] = ((doc.approved_paths || []) + paths).uniq

        doc.attributes = new_attrs
        # doc.save(validate: false)

        doc.correct_paths
        Document.where(:id => doc.id).update_all(belongs_to_paths: doc.belongs_to_paths, approved_paths: doc.approved_paths, 
              not_approved_paths: doc.not_approved_paths, not_accountable_for: doc.not_accountable_for, updated_by_id: user.id)
        doc.create_logs({ user_id: user.id, action: ActivityLog::ACTIONS[:updated_document], 
              attrs_changes: doc.changes })

        next if user_ids_in_paths.blank?
        # Update UserDocument relationship for syncing
        DocumentService.delay(queue: "update_data").add_accountable_to_paths(company, doc, paths, {user_ids_in_paths: user_ids_in_paths})
      end
    when "remove_accountability"
      # Document is already accountable and/or Accountable but not approved: Remove accountability.
      # Document is not accountable. Do nothing.

      user_ids_in_paths = company.user_companies.where(:company_path_ids.in => paths).pluck(:user_id)

      documents.each do |doc|
        doc = Document.get_document(doc)
        next if doc.nil? || doc.is_private

        new_attrs[:belongs_to_paths] = (doc.belongs_to_paths || []) - paths
        
        doc.attributes = new_attrs
        # doc.save(validate: false)

        doc.correct_paths
        Document.where(:id => doc.id).update_all(belongs_to_paths: doc.belongs_to_paths, approved_paths: doc.approved_paths, 
              not_approved_paths: doc.not_approved_paths, not_accountable_for: doc.not_accountable_for, updated_by_id: user.id)
        doc.create_logs({ user_id: user.id, action: ActivityLog::ACTIONS[:updated_document], 
              attrs_changes: doc.changes })

        next if user_ids_in_paths.blank?
        # Update UserDocument relationship for syncing
        DocumentService.delay(queue: "update_data").remove_accountability_of_paths(company, doc, paths, {user_ids_in_paths: user_ids_in_paths})
      end
    else
      return {success: false, message: "There are something wrong"}
    end

    result
  end

  ##
  # Get logs of document in a company
  ##
  def logs
    activity_logs.all.with(collection: "#{company_id}_activity_logs")
  end

  ##
  # create logs of document in a company
  # log_hash = {user: user_id, action: ActivityLog::ACTIONS[:unfavourite_document]}
  ##
  def create_logs(log_hash)
    log_hash[:target_document_id] = self.id
    log_hash[:company_id] = self.company_id

    # puts "---document #{self.title} create_logs for company #{company.id} #{company.name}---"
    # puts log_hash

    # ActivityLog.with(collection: "#{self.company_id}_activity_logs").create(log_hash)
    LogService.delay.create_log(self.company_id, log_hash)
  end

  ##
  # Get users that are related with this document in a company
  ##
  def company_users(company)
    user_documents.all.with(collection: "#{company.id}_user_documents")
  end

  ##
  # create user_document of user and document in a company
  # hash = {user_id, is_accountable, is_favourited, is_read}
  ##
  def create_user_document(company, hash)
    hash[:document_id] = self.id

    if self.favourited_user_ids.include?(hash[:user_id])
      hash[:is_favourited] = true
    end

    if self.read_user_ids.include?(hash[:user_id])
      hash[:is_read] = true
    end

    u_doc = company_users(company).where(user_id: hash[:user_id])

    if u_doc.count > 0
      hash[:updated_at] = Time.now.utc
      u_doc.update_all(hash)
    else
      UserDocument.with(collection: "#{company.id}_user_documents").create(hash)
    end
  end

  ##
  #
  ##
  def self.get_document(doc_obj)
    if doc_obj.is_a?(Document)
      doc_obj
    elsif doc_obj.is_a?(DocumentContent)
      doc_obj.document 
    elsif doc_obj.is_a?(Hash)
      Document.find(doc_obj["document_id"]) rescue nil
    else 
      Document.find(doc_obj) rescue nil
    end
  end

  def self.approval_expiration_time
    Time.now.advance(minutes: -5).utc
  end
end