require 'open-uri'

class User
  include Mongoid::Document
  include Mongoid::Paperclip
  include Mongoid::Timestamps
  include Mongoid::Search

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :trackable, :rememberable, :recoverable
         #:registerable, :validatable

  ## Database authenticatable
  field :email,              type: String, default: ""
  field :encrypted_password, type: String, default: ""

  ## Recoverable
  field :reset_password_token,   type: String
  field :reset_password_sent_at, type: Time

  ## Rememberable
  field :remember_created_at, type: Time

  ## Trackable
  field :sign_in_count,      type: Integer, default: 0
  field :current_sign_in_at, type: Time
  field :last_sign_in_at,    type: Time
  field :current_sign_in_ip, type: String
  field :last_sign_in_ip,    type: String

  field :admin, type: Boolean, default: false

  ## Confirmable
  # field :confirmation_token,   type: String
  # field :confirmed_at,         type: Time
  # field :confirmation_sent_at, type: Time
  # field :unconfirmed_email,    type: String # Only if using reconfirmable

  ## Lockable
  # field :failed_attempts, type: Integer, default: 0 # Only if lock strategy is :failed_attempts
  # field :unlock_token,    type: String # Only if unlock strategy is :email or :both
  # field :locked_at,       type: Time

  has_mongoid_attached_file :avatar, styles: { thumb: ["100x100#", :jpg],
                                                iphone4: ["464x464#", :jpg] },
                                    convert_options: {all: ["-unsharp 0.3x0.3+5+0", "-quality 90%", "-auto-orient"]},
                                    processors: [:thumbnail] ,
                                    storage: Rails.env.production? ? :s3 : :filesystem,
                                    s3_permissions: :public_read,
                                    s3_credentials: {access_key_id: CONFIG['amazon_access_key'],
                                                     secret_access_key: CONFIG['amazon_secret'],
                                                     bucket: CONFIG[:bucket]},
                                    default_url: "https://s3.amazonaws.com/shok-prod/missing-:style.png"

  validates_attachment_content_type :avatar, :content_type => %w(image/png image/jpg image/jpeg image/gif)

  field :name, type: String
  field :nickname, type: String

  field :token, type: String

  field :home_email, type: String, default: ""

  field :email_downcase, type: String
  field :home_email_downcase, type: String, default: ""

  field :active, type: Boolean, default: true

  #For checking user has setup his/her account setting
  field :has_setup, type: Boolean, default: false

  field :has_reset_pass, type: Boolean, default: false

  field :push_token, type: String
  field :platform, type: String
  field :app_access_token, type: String
  field :device_name, type: String
  field :os_version, type: String

  #field :allow_sync, type: Boolean, default: true

  field :mark_as_read, type: Boolean
  field :remind_mark_as_read_later, type: Boolean

  ##
  field :super_help_desk_user, type: Boolean
  field :employee_number, type: Integer

  field :updated_by_admin, type: Boolean

  field :phone, type: String, default: ""

  #store information of user company relationship (like user_company object)
  # { company_id => {} }
  field :user_companies_info, type: Hash, default: {}

  validates_presence_of :name, :email, :token

  validates_uniqueness_of :token, :email

  validates :email, format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i }
  validates :password, format: {with: /^(?=.*[a-z])(?=.*[A-Z])(?=.*[0-9]).{10,}$/, :multiline => true, 
    allow_blank: true, message: "is not strong, must to be mix of upper, lower, numbers, and min length is 10 chars" }

  has_and_belongs_to_many :favourite_documents, class_name: "Document", inverse_of: :favourited_users

  has_and_belongs_to_many :read_documents, class_name: "Document", inverse_of: :read_users

  has_many :created_documents, class_name: "Document", inverse_of: :created_by
  has_many :updated_documents, class_name: "Document", inverse_of: :updated_by

  has_many :private_documents, class_name: "Document", inverse_of: :private_for

  #has_many :approved_documents, class_name: "Document", inverse_of: :approved_by

  #Relationship Approver - Document
  has_and_belongs_to_many :approved_documents, class_name: "User", inverse_of: :approved_bys
  has_many :approver_documents

  has_many :devices, class_name: "UserDevice", inverse_of: :user, dependent: :destroy, validate: false

  has_and_belongs_to_many :companies, class_name: "Company", inverse_of: :users

  has_many :user_companies

  has_many :activity_logs, order: [:action_time, :desc], inverse_of: :user

  has_many :target_activity_logs, class_name: "ActivityLog", order: [:action_time, :desc], inverse_of: :target_user

  has_many :notifications, order: [:created_at, :desc]

  has_many :report_settings

  has_many :user_documents

  belongs_to :updated_by, class_name: "User"

  search_in :name, :email_downcase, :home_email_downcase

  index({token: 1})

  index({email_downcase: 1})

  scope :active, -> {where(active: true)}
  scope :admin, -> {where(admin: true)}

  before_validation do
    self.token = User.access_token if self.token.blank? && self.new_record?

    self.email_downcase = email.to_s.downcase if email_changed?

    self.home_email_downcase = home_email.to_s.downcase if home_email_changed?

    self.nickname = self.name
  end

  #update has_setup
  before_save do
    unless self.new_record?
      if (home_email_changed? || encrypted_password_changed?)
        self.has_setup = true
        self.has_reset_pass = false
      end
    end

    # #If you remove "Has setup" from a user's profile and that user logs into the system via web portal:
    # #It should show password change form and the widget asking if they want to mark documents as read and understood.
    if has_setup_changed? && !has_setup
      self.remind_mark_as_read_later = true
    end

    true
  end

  after_save do
    # mark all as read
    if mark_as_read_changed? && mark_as_read && updated_by_id == self.id
      self.read_all_documents!
    end

    # Create new device when push_token is changed
    if push_token_changed? && push_token
      u_d = self.devices.find_or_initialize_by({token: push_token, app_access_token: app_access_token})
      is_new_device = (u_d.new_record? || u_d.deleted)
      u_d.update_attributes({platform: platform, device_name: device_name, os_version: os_version, deleted: false})

      unless is_new_device
        NotificationService.delay.register_device(self, push_token, app_access_token)
        UserDevice.delay.disable_invalid_devices(u_d)
      end

      User.where(:id => self.id).update_all({push_token: nil, app_access_token: nil, platform: nil, device_name: nil, os_version: nil})
    end

    if name_changed?
      Permission.where(for_user_id: id.to_s).update_all(for_user_name: name)
    end

    sent_noti = false
    if active_changed? && !active
      NotificationService.delay.user_is_inactive(self)
      sent_noti = true
    end

    #sync user to campaign monitor
    if active_changed? 
      if active
        CampaignService.delay.create_subscriber(self)
      else
        CampaignService.delay.remove_subscriber(self)
      end

      self.user_companies.update_all(active: active)
    elsif name_changed?
      CampaignService.delay.update_subscriber(self) if active
    end

    if company_ids_changed?
      old_comp_ids = self.company_ids_was || []
      new_comp_ids = self.company_ids || []

      User.delay.update_companies_of_user(self, old_comp_ids, new_comp_ids)
    elsif name_changed?
      unless sent_noti
        NotificationService.delay.user_has_changed_info(self)
        sent_noti = true
      end
    end

    if updated_by_admin
      [:active, :name, :email, :phone, :home_email, :encrypted_password].each do |f|
        if self.send(:"#{f}_changed?")
          self.target_activity_logs.create({user_id: updated_by_id, action: ActivityLog::ACTIONS[:updated_user], attrs_changes: self.changes})
          break
        end
      end
    end
  end

  after_create do
    self.reset_password!({new_user: true})
  end

  def self.access_token
    random_token = SecureRandom.urlsafe_base64(nil, false)

    if user = User.where(:token => random_token).first
      return access_token
    end

    return random_token
  end

  def disabled!
    self.active = false
    self.save
  end

  def disabled?
    return false if admin? || super_help_desk_user?

    !active || company_ids.blank?
  end

  def is_approver?(comp, u_comp = nil)
    u_comp ||= user_company(comp)

    u_comp.try(:is_approver) || false
  end

  def is_supervisor?(comp, u_comp = nil)
    u_comp ||= user_company(comp)

    u_comp.try(:is_supervisor) || false
  end

  def first_name
    name.to_s.split(" ")[0]
  end

  ##
  # Get User Company information
  ##
  def user_company(comp, get_hash = false)
    if get_hash
      self.user_companies_info[comp.id.to_s] || {}
    else
      if comp.user_ids.include?(self.id)
        if self.new_record?
          user_companies.find_or_initialize_by({company_id: comp.id})
        else
          user_companies.find_or_create_by({company_id: comp.id})
        end
      else
        nil
      end
    end
  end

  ##
  # Get Permission of User in a Company
  ##
  def comp_permission(comp, u_comp = nil, u_comp_is_hash = false)
    u_comp ||= user_company(comp, u_comp_is_hash)

    if u_comp_is_hash
      comp.permissions.where(id: u_comp["permission_id"]).first
    else
      u_comp.permission rescue nil
    end
  end

  def reset_password!(options = {new_user: false})
    new_password = String.generate_key(:all, 10)
    
    new_attrs = {has_setup: false, has_reset_pass: true}

    if options[:new_user]
      UserMailer.delay.confirmation(self, new_password)
      new_attrs[:has_reset_pass] = false
    else
      UserMailer.delay.forgot_password(self, new_password)
    end

    self.password = new_password
    self.password_confirmation = new_password
    self.save(validate: false)

    User.where(:id => self.id).update_all(new_attrs)
    
    new_password
  end

  def avatar_from_url(url)
    self.avatar = open(url)
  end

  def avatar_iphone4_url
    self.avatar.url
  end

  ##
  # User read a document
  ##
  def read_document!(doc, action_time_str = nil)
    if doc.is_expiried
      return {error: I18n.t("document.is_expiried"), error_code: ERROR_CODES[:refresh_data] }
    end

    action_time = nil
    comp = doc.company
    act_log_hash = {target_document_id: doc.id, action: ActivityLog::ACTIONS[:read_document]}

    if !action_time_str.blank? && (action_time = (action_time_str.to_s.to_time.utc rescue nil))
      last_action = self.logs(comp).order([:action_time, :desc]).where(act_log_hash).first
      
      if last_action && last_action.action_time.utc >= action_time
        return {result_code: SUCCESS_CODES[:rejected], is_unread: !read_doc?(doc)}
      end
    end

    if read_doc?(doc)
      #return {error: I18n.t("document.already_read_before"), error_code: ERROR_CODES[:invalid_value] }
    else
      self.read_document_ids << doc.id
      self.save

      #Create log
      act_log_hash[:action_time] = action_time
      self.create_logs(comp, act_log_hash)

      UserService.update_user_documents_when_status_change({user: self, company: comp, document: doc})
    end

    {result_code: SUCCESS_CODES[:success], is_unread: false}
  end

  ##
  # User read a document
  ##
  def read_all_documents!
    new_read_doc_ids = []

    self.companies.each do |comp|
      unread_comp_doc_ids = docs(comp, "unread")[:docs].pluck(:id)

      unread_comp_doc_ids.each do |doc_id|
        new_read_doc_ids << doc_id

        #Create log
        self.create_logs(comp, {target_document_id: doc_id, action: ActivityLog::ACTIONS[:read_document]})
      end

      self.company_documents(comp).where({:document_id.in => unread_comp_doc_ids}).update_all({updated_at: Time.now.utc})
    end

    unless new_read_doc_ids.blank?
      self.read_document_ids = (self.read_document_ids || []) + new_read_doc_ids
      self.read_document_ids.uniq!
      self.save(validate: false)

      NotificationService.delay.mark_all_as_read(self)
    end

    {result_code: SUCCESS_CODES[:success]}
  end

  ##
  # User favourite a document
  ##
  def favour_document!(doc, action_time_str = nil)
    if doc.is_expiried
      return {error: I18n.t("document.is_expiried"), error_code: ERROR_CODES[:refresh_data] }
    end

    action_time = nil
    comp = doc.company
    act_log_hash = {target_document_id: doc.id, action: ActivityLog::ACTIONS[:favourite_document]}

    if !action_time_str.blank? && (action_time = (action_time_str.to_s.to_time.utc rescue nil))
      last_action = self.logs(comp).order([:action_time, :desc]).where(act_log_hash).first
      puts last_action.inspect
      if last_action && last_action.action_time.utc >= action_time
        return {result_code: SUCCESS_CODES[:rejected], is_favourite: favourited_doc?(doc)}
      end
    end

    if favourited_doc?(doc)
      #return {error: I18n.t("document.already_favour_before"), error_code: ERROR_CODES[:invalid_value] }
    else
      self.favourite_document_ids << doc.id
      self.save

      #Create log
      act_log_hash[:action_time] = action_time
      self.create_logs(comp, act_log_hash)

      UserService.update_user_documents_when_status_change({user: self, company: comp, document: doc})
    end

    {result_code: SUCCESS_CODES[:success], is_favourite: true}
  end

  ##
  # User unfavourite a document
  ##
  def unfavour_document!(doc, action_time_str = nil)
    if doc.is_expiried
      return {error: I18n.t("document.is_expiried"), error_code: ERROR_CODES[:refresh_data] }
    end

    action_time = nil
    comp = doc.company
    act_log_hash = {target_document_id: doc.id, action: ActivityLog::ACTIONS[:unfavourite_document]}

    if !action_time_str.blank? && (action_time = (action_time_str.to_s.to_time.utc rescue nil))
      last_action = self.logs(comp).order([:action_time, :desc]).where(act_log_hash).first

      if last_action && last_action.action_time.utc >= action_time
        return {result_code: SUCCESS_CODES[:rejected], is_favourite: favourited_doc?(doc)}
      end
    end

    if favourited_doc?(doc)
      self.favourite_document_ids.delete(doc.id)
      self.save

      #Create log
      act_log_hash[:action_time] = action_time
      self.create_logs(comp, act_log_hash)
      
      UserService.update_user_documents_when_status_change({user: self, company: comp, document: doc})
    else
      #return {error: I18n.t("document.not_favour_before"), error_code: ERROR_CODES[:invalid_value] }
    end

    {result_code: SUCCESS_CODES[:success], is_favourite: false}
  end

  ##
  # Get unread number of a list : unread / favourite / private
  ##
  def unread_number(company, type = "unread")
    docs(company, type)[:unread_number] rescue 0
  end

  ##
  # Query to get documents that user can see:
  # Add / Edit Documents:  
  #    - Can see all documents, except other users private documents.
  # Not Add / Edit Documents:  
  #    - Can see documents that are: 
  #       + (Active && Private for user) ||
  #       + ( 
  #           + Active && Public &&
  #           + (  
  #               Accountable || 
  #               (Not Accountable && Not Restricted) || 
  #               (Not Accountable && Restricted && Restrict for user's areas)
  #             )
  #         )
  #    - Cannot see other user's private documents.
  # Is Approver (Advanced and Hybrid Company): Line above + unapproved documents assigned to their area.
  #
  # # - Approval documents that are "to be approved" if not restricted are findable 
  #     (appear in search, it's All category, All) as non-accountable
  ##
  def query_documents(company, options = {types: "all"})
    return {} if admin || super_help_desk_user

    u_comp = user_company(company, true)

    if u_comp.nil?
      #no documents
      return {:created_at => nil, :updated_at => nil}
    end

    query = {}
    query_not_private = {is_private: false}
    query["$or"] = [{is_private: true, private_for_id: self.id}]
    
    can_add_edit_document = PermissionService.can_add_edit_document(self, company, u_comp)

    if can_add_edit_document
      if options[:types] != "accountable"
        query["$or"] << query_not_private
      else
        query_belongs_to = {is_private: false, approved_paths: /^#{u_comp["company_path_ids"]}/i }

        query["$or"] << query_belongs_to
      end
    else
      query.merge!({:effective_time.lte => Time.now.utc, active: true})

      if options[:types] != "accountable"
        query_not_private[:restricted] = false
        query["$or"] << query_not_private

        paths_key = :belongs_to_paths
      else
        paths_key = :approved_paths
      end
      
      query_belongs_to = {is_private: false}
      query_belongs_to[paths_key] = /^#{u_comp["company_path_ids"]}/i

      query["$or"] << query_belongs_to
    end

    query
  end

  ##
  # which are all the company documents: (see comment in query_documents method)
  ##
  def all_docs(company, order = [:created_at, :desc])
    company.documents.where( query_documents(company) ).order(order)
  end

  ##
  # Get new documents: (for sync document between iOs/Android app with web portal)
  # Can sync:
  #   - private document ||
  #   - (
  #        + effective && 
  #        +  (
  #             + Accountable || 
  #             + (Not Accountable && Not Restricted && are favourite by user) || 
  #             + (Not Accountable && Restricted && restrict for user's areas && are favourite by user)
  #           )
  #      )
  # if accountable documents (and approved if advanced).
  # or non-accountable documents that are not restricted and are favourite by user 
  # or private documents of user
  # @params:
  #   company   
  #   options: {order: , after_timestamp: , synced_doc_ids: []}
  ##
  def new_docs(company, options = {})
    order = options[:order] || [:created_at, :desc]

    return company.documents.order(order) if admin || super_help_desk_user

    u_comp = user_company(company, true)

    if u_comp.nil? || u_comp["company_path_ids"].blank?
      #no documents
      return Document.where(:created_at => nil, :updated_at => nil)
    end

    query = {}
    query["$or"] = [{is_private: false, :approved_paths => /^#{u_comp["company_path_ids"]}/i},
      {is_private: true, private_for_id: self.id}, 
      {restricted: false, :favourited_user_ids.in => [self.id]}]

    documents = 
      if last_timestamp = (options[:after_timestamp].to_s.to_time.utc rescue nil)
        all_doc_ids = company.documents.where(query).pluck(:id)

        new_doc_ids = company_documents(company).available_for_sync.where({:updated_at.gte => last_timestamp}).pluck(:document_id)
        need_sync_doc_ids = (new_doc_ids & all_doc_ids)

        company.documents.where({:id.in => need_sync_doc_ids})
      else
        company.documents.where(query)
      end

    documents.effective.order(order)
  end

  ##
  # When the app sync docs for a user, need to return the non-accountable docs (that have just remove accountbility)
  #   and mark them as inactive
  # These docs will be removed from the app
  # @params:
  #   company   
  #   options: {after_timestamp}
  ##
  def docs_need_remove_in_app(company, options = {})
    comp_docs = company_documents(company).not_available_for_sync

    if last_timestamp = (options[:after_timestamp].to_s.to_time.utc rescue nil)
      comp_docs = comp_docs.where({:updated_at.gte => last_timestamp.advance(days: -1)})
    end

    doc_ids = comp_docs.pluck(:document_id)
    new_sync_doc_ids = new_docs(company).pluck(:id)
    need_remove_doc_ids = doc_ids - new_sync_doc_ids

    #available for sync but not effective or inactive
    available_for_sync_doc_ids = company_documents(company).available_for_sync.pluck(:document_id)
    not_effective_doc_ids = company.documents.where(effective: false, is_private: false, :id.in => available_for_sync_doc_ids).pluck(:id)
    inactive_doc_ids = company.documents.where(active: false, is_private: false, :id.in => available_for_sync_doc_ids).pluck(:id)

    need_remove_doc_ids += not_effective_doc_ids
    need_remove_doc_ids += inactive_doc_ids
    
    company.documents.where(:id.in => need_remove_doc_ids)
  end

  ##
  # Get Docs in a list (favourite / unread / private)
  # - Remove all inactive documents from All and the sub categories
  # types: "all"/"accountable"
  ##
  def docs(company, filter = "favourite", order = [:created_at, :desc], types = "all")
    result = {docs: [], unread_number: 0, need_count_unread_number: false}

    read_ids = read_document_ids + private_document_ids

    if filter == "favourite"
      # Only sees their favourite documents and can Read Document.
      available_docs = all_docs(company, order)
      result[:docs] = available_docs.active.where({:id.in => favourite_document_ids})
      result[:need_count_unread_number] = true

    elsif filter == "unread"
      # Only documents that are accountable to that users area, and have not been read by that user.
      result[:docs] = assigned_docs(company).where(:id.nin => read_ids)
      result[:unread_number] = result[:docs].count

    elsif filter == "private"
      result[:docs] = company.documents.active.private_with(self).order(order)

    elsif filter == "to_approve"
      result[:docs] = docs_to_approve(company, order)

    elsif filter == "inactive"
      available_docs = all_docs(company, order)
      result[:docs] = available_docs.inactive

    else #all
      #Add / Edit Documents: Can see all documents that are: Active. except other users private documents.
      #All other users: Can see all documents in the division the user belongs to that are: 
      #                 Active && Not Restricted. Cannot see other user's private documents
      query = query_documents(company, {types: types})

      result[:docs] = company.documents.active.where( query ).order(order)
      result[:need_count_unread_number] = true
    end

    if result[:need_count_unread_number]
      doc_ids = result[:docs].pluck(:id)
      result[:unread_number] = assigned_docs(company).where(:id.in => (doc_ids - read_ids)).count
    end

    result
  end

  ##
  # Docs that are assigned to the part of organisation that user is belonged to
  # -> Accountable
  ##
  def assigned_docs(company, u_comp = nil, order = [:created_at, :desc])
    return company.documents.active.public_all.order(order) if admin || super_help_desk_user

    u_comp ||= user_company(company, true)

    if u_comp.nil? || u_comp["company_path_ids"].blank?
      #no documents
      return Document.where(:created_at => nil, :updated_at => nil)
    end

    Document.accountable_documents_for_area(company, u_comp["company_path_ids"]).order(order)
  end

  ##
  # Just for approver: 
  # Unapproved documents assigned to the Approvers area.
  # Approver can not see the document if they have approved/rejected it
  ##
  def docs_to_approve(company, order = [:created_at, :desc])
    u_comp = user_company(company, true)

    if u_comp.nil? || u_comp["approver_path_ids"].blank? || !u_comp["is_approver"]
      #no documents
      return Document.where(:created_at => nil, :updated_at => nil)
    end

    query = {:not_approved_paths.in => u_comp["approver_path_ids"], 
      active: true, :approved_by_ids.nin => [self.id]}

    company.documents.public_all.where(query).order(order)
  end

  def favourited_doc?(doc)
    favourite_document_ids.include?(doc.id)
  end

  def read_doc?(doc)
    read_document_ids.include?(doc.id)
  end

  def private_doc?(doc)
    private_document_ids.include?(doc.id)
  end

  def is_belongs_to_company(company)
    self.company_ids.include?(company.id)
  end

  ##
  # Check user is required to read document or not
  ##
  def is_required_to_read_doc?(company, doc)
    if doc.is_private
      false
    else
      is_accountable_doc?(company, doc)
    end
  end

  ##
  # Check a doc is accoutable for user or not
  # only accountable when doc belong to user area
  ##
  def is_accountable_doc?(company, doc)
    u_comp = user_company(company, true) || {}
    doc.is_not_restrict_viewing && doc.approved_paths.include?(u_comp["company_path_ids"])
  end

  ##
  # Return total docs size that user's device will sync
  ##
  def total_docs_size(company = nil)
    total = 0

    u_companies = company ? [company] : companies.active

    u_companies.each do |comp|
      total += new_docs(comp).sum(:curr_version_size)
    end

    total
  end

  ##
  # Return docs size for each category: private / favourite / unread
  ##
  def docs_size(company = nil, filter = "private")
    total = 0

    if company
      u_companies = [company]
    else
      if admin || super_help_desk_user
        u_companies = Company.all
      else
        u_companies = companies.active
      end
    end

    u_companies.each do |comp|
      next if (!admin && !super_help_desk_user && user_company(comp).nil?)
      
      available_docs = docs(comp, filter)[:docs]

      total += available_docs.sum(:curr_version_size)
    end

    total
  end

  ##
  # _method: "put"
  # authenticity_token: "klF3Wt78C0JbDgyfdW9+0BnpFVPtHJ8hXb/vNxh4gDk="
  # custom_permissions: Object
  # user[email]: "vuongtieulong02@gmail.com"
  # user[name]: "Gagoit"
  # user[permission_id]: "Custom Permission"
  # user[company_path_ids]:
  # user[approver_paths]:
  # user[supervisor_paths]:
  # utf8: "✓"
  ##
  def update_info(current_user, comp, params)
    new_user_attrs = {}
    user_changes = {}
    [:active, :email, :name, :phone, :home_email, :password, :password_confirmation, :updated_by_id].each do |field|
      if params["user"].has_key?(field.to_s)
        new_user_attrs[field] = params["user"][field.to_s]

        if field != :updated_by_id && self[field] && self[field] != new_user_attrs[field]
          user_changes[field.to_s] = [self[field], new_user_attrs[field]]
        end
      end
    end

    if (new_user_attrs.has_key?(:password) || new_user_attrs.has_key?(:password_confirmation)) && new_user_attrs[:password] != new_user_attrs[:password_confirmation]
      return {success: false, message: "Please check that you've entered and confirmed your password!", error_code: "password"}
    end

    unless comp.user_ids.include?(self.id)
      comp.user_ids = (comp.user_ids || []) << self.id
      self.company_ids = (self.company_ids || []) << comp.id
    end

    u_comp = user_company(comp)

    if u_comp.nil?
      return {success: false, message: "User #{self.name} is not in company #{comp.name}", error_code: "user_company"}
    end

    u_comp_attrs = {}

    if params["user"].has_key?("permission_id")
      new_perm_attrs = {}

      perm_id = params["user"]["permission_id"]
      if perm_id == Permission::CUSTOM_PERMISSION_CODE
        new_perm_attrs = params["custom_permissions"]

        custom_perm = comp.permissions.find_or_initialize_by({
          name: Permission.custom_perm_name(self.id)
        })

        custom_perm.for_user_id = self.id.to_s
        custom_perm.for_user_name = params["user"]["name"]
        custom_perm.is_custom = true
        custom_perm.user_type = params["user"]["user_type"]
        custom_perm.code = "custom_code_#{custom_perm.name.to_s.downcase.gsub(' ', '_')}"

        ## Keep permissions for user that current user can not access to
        if current_perm = u_comp.permission
          Permission::RULES.each_key do |key|
            custom_perm[key] = current_perm[key]
          end
        end

        can_edit_perms = PermissionService.available_perms(current_user, comp)

        new_perm_attrs.each_key do |key|
          key_sym = key.to_sym
          next unless can_edit_perms.include?(key_sym)

          custom_perm[key_sym] = new_perm_attrs[key]
        end

        if custom_perm.save
          perm_id = custom_perm.id
        else
          return {success: false, message: "Permission has an error: #{custom_perm.errors.full_messages.join(", ")}", error_code: "permission"}
        end

      elsif custom_perm = comp.permissions.where(id: perm_id).first
        comp.permissions.where(name: Permission.custom_perm_name(self.id), :id.ne => custom_perm.id).first.try(:destroy)
      else
        return {success: false, message: "Permission has not found", error_code: "permission"}
      end

    else
      custom_perm = u_comp.permission
    end

    u_comp_attrs[:user_type] = custom_perm.try(:user_type)

    unless PermissionService.has_perm_add_edit_user(current_user, comp, nil, custom_perm[:user_type])
      return {success: false, message: "You can not add user as #{Permission::STANDARD_PERMISSIONS[custom_perm.try(:user_type).try(:to_sym)][:name]}", error_code: "permission"}
    end

    u_comp_attrs[:permission_id] = custom_perm.try(:id)

    ##company_path_ids
    if params["user"].has_key?("company_path_ids")
      check_comp_path = User.check_company_path_ids(comp, params["user"]["company_path_ids"])
      if check_comp_path[:valid]
        company_path_ids = params["user"]["company_path_ids"]
      else
        return {success: false, message: check_comp_path[:message], error_code: "error_company_paths"}
      end

      u_comp_attrs[:company_path_ids] = company_path_ids
    end

    #approver / supervisor paths
    if params["user"].has_key?("approver_paths")
      approver_path_ids = ActiveSupport::JSON.decode(params["user"]["approver_paths"]) rescue []

      u_comp_attrs[:approver_path_ids] = approver_path_ids
    end

    if params["user"].has_key?("supervisor_paths")
      supervisor_path_ids = ActiveSupport::JSON.decode(params["user"]["supervisor_paths"]) rescue []

      u_comp_attrs[:supervisor_path_ids] = supervisor_path_ids
    end

    #u_comp_attrs[:show_admin_detail] = params["user"]["show_admin_detail"] if params["user"].has_key?("show_admin_detail")

    new_user_attrs[:updated_by_admin] = false

    if self.update_attributes(new_user_attrs)
      result = {success: true, message: "User has been updated successfully"}

      ##Create log for company_path_ids, approver_path_ids, supervisor_path_ids, permission
      [:company_path_ids, :approver_path_ids, :supervisor_path_ids, :permission_id].each do |e|
        if u_comp_attrs.has_key?(e) && u_comp_attrs[e] != u_comp[e]
          user_changes[e.to_s] = [u_comp[e], u_comp_attrs[e]] 
        end
      end

      log_type = self.new_record? ? ActivityLog::ACTIONS[:created_user] : ActivityLog::ACTIONS[:updated_user]

      comp.create_logs({target_user_id: self.id, user_id: updated_by_id, action: log_type, attrs_changes: user_changes}) unless user_changes.blank?

      u_comp.update_attributes(u_comp_attrs)
      u_comp.reload
      self.reload

      result[:load_approver_supervisor] = u_comp.is_approver || u_comp.is_supervisor
      result[:is_custom_perm] = custom_perm.try(:is_custom) || true
      result[:u_comp_perm] = custom_perm

      return result
    else
      return {success: false, message: self.errors.full_messages.first, error_code: self.errors}
    end
  end

  ##when doc have new version/ or is inactive, remove it from read list of all user
  ##when doc have new version/ or is inactive, remove it from favourite list of all user
  def remove_invalid_docs(invalid_doc_ids, in_list = [:read, :favourite, :private])
    if in_list.include?(:read) && !self.read_document_ids.blank?

      same_ids = (self.read_document_ids || []) & invalid_doc_ids
      unless same_ids.blank?
        self.read_document_ids = self.read_document_ids - same_ids
        self.save(validate: false)
      end
    end

    if in_list.include?(:favourite) && !self.favourite_document_ids.blank?

      same_ids = (self.favourite_document_ids || []) & invalid_doc_ids
      unless same_ids.blank?
        self.favourite_document_ids = self.favourite_document_ids - same_ids
        self.save(validate: false)
      end
    end

  end

  def self.remove_invalid_docs(u_ids, invalid_doc_ids, in_list = [:read, :favourite, :private])
    users = if u_ids == "all"
      User.all
    else
      User.where(:id.in => u_ids)
    end

    users.any_of({:read_document_ids.in => invalid_doc_ids}, {:favourite_document_ids.in => invalid_doc_ids}, {:private_document_ids.in => invalid_doc_ids}).each do |u|
      u.remove_invalid_docs(invalid_doc_ids, in_list)
    end
  end

  def self.update_companies_of_user(user, old_comp_ids = [], new_comp_ids = [])
    removed_comp_ids = (old_comp_ids-new_comp_ids)
    added_comp_ids = (new_comp_ids-old_comp_ids)
    if new_comp_ids.blank?
      NotificationService.delay.user_is_inactive(user)
    elsif user.active
      NotificationService.delay.users_companies_have_been_changed(removed_comp_ids, [user.id], :removed)
      NotificationService.delay.users_companies_have_been_changed(added_comp_ids, [user.id], :added)
    end

    invalid_doc_ids = []
    Company.where(:id.in => removed_comp_ids).each do |comp|
      invalid_doc_ids += (comp.document_ids || [])

      user.remove_company(comp)
    end

    invalid_doc_ids.uniq!

    user.remove_invalid_docs(invalid_doc_ids)

    #Create default user_comp & permission
    Company.where(:id.in => added_comp_ids).each do |comp|
      user.add_company(comp)
    end
  end

  ##
  # Remove user from a company
  # destroy user_comp & customer permission for this user in removed company
  ##
  def remove_company(comp)
    if u_comp = user_company(comp)
      u_comp_perm = u_comp.permission
      if u_comp_perm && u_comp_perm.is_custom && !Permission::STANDARD_PERMISSIONS.keys.include?(u_comp_perm.code.to_sym)
        u_comp_perm.destroy
      end

      u_comp.destroy
    end
  end

  ##
  # Add user to a company
  # Create default user_comp & permission
  ##
  def add_company(comp, options = {})
    options ||= {}
    u_comp = self.user_companies.find_or_initialize_by({:company_id => comp.id})

    u_comp.company_path_ids = options[:company_path_ids] if options.has_key?(:company_path_ids)
    u_comp.approver_path_ids = options[:approver_path_ids] if options.has_key?(:approver_path_ids)
    u_comp.supervisor_path_ids = options[:supervisor_path_ids] if options.has_key?(:supervisor_path_ids)

    if options[:permission_id]
      u_comp.permission_id = options[:permission_id]
    elsif (u_comp_perm = u_comp.permission).nil?
      u_comp.permission_id = comp.permission_standard.try(:id)
    end

    u_comp.active = active

    u_comp.save
  end

  ##
  # Check company path for a user
  ##
  def self.check_company_path_ids(comp, path_ids, field = :id)
    comp_all_paths_hash = comp.all_paths_hash

    paths_hash = (field == :id) ? comp_all_paths_hash : comp_all_paths_hash.invert

    if paths_hash[path_ids]
      {valid: true}
    else
      {valid: false, message: "Company area is invalid."}
    end
  end

  ##
  #
  ##
  def self.get_all(current_user, comp, page, per_page, search, sort)
    users = comp.users.full_text_search(search.downcase)

    users = users.order_by(sort).page(page).per(per_page)

    return_data = {
      "aaData" => [],
      "iTotalDisplayRecords" => users.length,
      "iTotalRecords" => users.total_count
    }

    comp_all_paths_hash = comp.all_paths_hash

    u_companies = {}
    UserCompany.where(company_id: comp.id).pluck(:user_id, :company_path_ids, :approver_path_ids, :permission_id).each do |u_c|
      u_companies[u_c[0]] = [u_c[1], u_c[2], u_c[3]] #:company_path_ids, :approver_path_ids, :permission_id
    end

    comp_perms = {}
    Permission.where(company_id: comp.id).each do |perm|
      comp_perms[perm.id] = perm
    end

    has_perm = nil
    if current_user.admin? || current_user.super_help_desk_user?
      has_perm = true 
    else
      current_u_comp = u_companies[current_user.id] || []
      unless current_u_comp_perm = comp_perms[current_u_comp[2]]
        has_perm = false
      end
    end

    users.each do |user|
      u_comp = u_companies[user.id] || []

      unread_docs, total_count = Document.get_all(user, comp, {page: nil, per_page: nil, search: "", sort_by: [:title, :asc], filter: "unread"})
      unread_docs_title = unread_docs.limit(3).pluck(:title)
      unread_docs_length = unread_docs.count

      data = {
        name: user.name,
        email: user.email,
        home_email: user.home_email,
        emails: [user.email, user.home_email].reject{|e| e.blank?}.join(", "),
        path: comp_all_paths_hash[u_comp[0]],
        path_id: u_comp[0],
        unread_docs: unread_docs_title.join(", "),
        unread_docs_length: unread_docs_length,
        id: user.id.to_s,
        active: user.active,
        edit_url: Rails.application.routes.url_helpers.edit_user_path(user),
        has_perm: current_user.id == user.id,
        load_more_unread_docs_url: Rails.application.routes.url_helpers.load_more_unread_docs_user_path(user),
        can_mark_all_as_read: (current_user.admin? || current_user.super_help_desk_user?),
        mark_all_as_read_url: Rails.application.routes.url_helpers.mark_all_as_read_user_path(user)
      }

      unless data[:has_perm]
        if has_perm.nil?
          u_comp_perm = comp_perms[u_comp[2]]
          u_type = u_comp_perm.is_custom ? Permission::STANDARD_PERMISSIONS[:standard_user][:code] : u_comp_perm.code

          data[:has_perm] = current_u_comp_perm["add_edit_#{u_type}".to_sym] || false
        else
          data[:has_perm] = has_perm
        end
      end
      
      return_data["aaData"] << data
    end

    return_data
  end

  ##
  # Add / Edit User Permissions: Can only see users that they can edit
  # Supervisor User: Can only see users that belong in their section(s) they supervise for
  ##
  def self.get_available_users(current_user, comp, page, per_page, search, sort)
    comp_all_paths_hash = comp.all_paths_hash

    has_perm = nil
    current_u_comp = nil
    if current_user.admin? || current_user.super_help_desk_user?
      has_perm = true 
    else
      current_u_comp = current_user.user_company(comp)
      if current_u_comp.nil? || (current_u_comp_perm = current_u_comp.permission).nil?
        has_perm = false
      end
    end

    can_edit_user_types = []
    Permission::STANDARD_PERMISSIONS.keys.each do |key|
      u_type = Permission::STANDARD_PERMISSIONS[key][:code]

      can_edit_user_types << u_type if (has_perm || (current_u_comp_perm && current_u_comp_perm["add_edit_#{u_type}"]))
    end

    available_user_ids = comp.user_companies.where(:user_type.in => can_edit_user_types).pluck(:user_id)

    # ok, so when supervisor have at least one add/edit user permission
    # we will not show the users in his team if he don't have permission edit their users
    # and in case supervisor have no add/edit user permission, he will see all users in his team, but just view, no edit
    supervise_for_user_ids = []
    if available_user_ids.blank? && current_u_comp && current_u_comp.is_supervisor && !current_u_comp.supervisor_path_ids.blank?
      supervise_for_user_ids = comp.user_companies.where(:company_path_ids.in => current_u_comp.supervisor_path_ids).pluck(:user_id)
    end

    users = comp.users.where(:id.in => (available_user_ids + supervise_for_user_ids) ).full_text_search(search.downcase)

    users = users.order_by(sort).page(page).per(per_page)

    return_data = {
      "aaData" => [],
      "iTotalDisplayRecords" => users.length,
      "iTotalRecords" => users.total_count
    }

    users.each do |user|
      u_comp = user.user_company(comp, true)

      unread_docs, total_count = Document.get_all(user, comp, {page: nil, per_page: nil, search: "", sort_by: [:title, :asc], filter: "unread"})
      unread_docs_title = unread_docs.limit(3).pluck(:title)
      unread_docs_length = unread_docs.count

      data = {
        name: user.name,
        email: user.email,
        home_email: user.home_email,
        emails: [user.email, user.home_email].reject{|e| e.blank?}.join(", "),
        path: comp_all_paths_hash[u_comp["company_path_ids"]],
        path_id: u_comp["company_path_ids"],
        unread_docs: unread_docs_title.join(", "),
        unread_docs_length: unread_docs_length,
        id: user.id.to_s,
        active: user.active,
        edit_url: Rails.application.routes.url_helpers.edit_user_path(user),
        load_more_unread_docs_url: Rails.application.routes.url_helpers.load_more_unread_docs_user_path(user),
        can_mark_all_as_read: (current_user.admin? || current_user.super_help_desk_user?),
        mark_all_as_read_url: Rails.application.routes.url_helpers.mark_all_as_read_user_path(user)
      }

      data[:has_perm] = (current_user.id == user.id) || available_user_ids.include?(user.id)

      unless data[:has_perm]
        if has_perm.nil?
          data[:has_perm] = (current_u_comp_perm["add_edit_#{u_comp[3]}"] rescue false) || false
        else
          data[:has_perm] = has_perm
        end
      end
      
      return_data["aaData"] << data
    end

    return_data
  end

  ##
  # bulk assign many users to a different part of the organisation
  ##
  def self.update_path(current_user, comp, search = '', user_ids, paths)

    check_comp_path = check_company_path_ids(comp, paths)
    unless check_comp_path[:valid]
      return {success: false, message: check_comp_path[:message], error_code: "error_company_paths"}
    end

    search = search.to_s.downcase.strip

    users = search.blank? ? comp.users : comp.users.full_text_search(search.downcase)

    has_perm = nil
    current_u_comp = nil
    if current_user.admin? || current_user.super_help_desk_user?
      has_perm = true 
    else
      current_u_comp = current_user.user_company(comp)
      if current_u_comp.nil? || (current_u_comp_perm = current_u_comp.permission).nil?
        has_perm = false
      end
    end

    can_edit_user_types = []
    Permission::STANDARD_PERMISSIONS.keys.each do |key|
      u_type = Permission::STANDARD_PERMISSIONS[key][:code]

      can_edit_user_types << u_type if (has_perm || (current_u_comp_perm && current_u_comp_perm["add_edit_#{u_type}"]))
    end

    available_user_ids = comp.user_companies.where(:user_type.in => can_edit_user_types).pluck(:user_id)

    if user_ids == "all"
      can_edit_user_ids = available_user_ids
    else
      can_edit_user_ids = (user_ids & available_user_ids.map { |e| e.to_s })
    end

    users = users.where(:id.in => can_edit_user_ids)

    users.each do |user|
      user.add_company(comp, {company_path_ids: paths})
    end

    {success: true, message: "User(s) has/have been assigned to a part of the organisation successfully"}
  end

  ##
  #
  ##
  def self.export_csv(current_user, comp, search = '', sort = [[:name, :asc]], user_ids= "all")
    comp_all_paths_hash = comp.all_paths_hash

    can_edit_user_types = PermissionService.can_edit_user_types(current_user, comp)

    user_query = {:user_type.in => can_edit_user_types}
    user_query.merge!({:user_id.in => user_ids}) if user_ids != "all"

    u_companies = {}
    available_user_ids = []
    comp.user_companies.where(user_query).pluck(:user_id, :company_path_ids, :approver_path_ids, :permission_id, :user_type).each do |u_c|
      u_companies[u_c[0]] = [u_c[1], u_c[2], u_c[3], u_c[4]] #:company_path_ids, :approver_path_ids, :permission_id, :user_type

      available_user_ids << u_c[0]
    end

    users = comp.users.where(:id.in => available_user_ids).full_text_search(search.downcase)
    users = users.order_by(sort)

    file = CSV.generate({:write_headers => true}) do |csv|
      csv << ["Name", "Email", "Backup Email", "Belongs To", "Unread Documents", "Active", "Created At"] ## Header values of CSV

      users.each do |user|
        u_comp = u_companies[user.id] || []
        
        unread_docs, total_count = Document.get_all(user, comp, {page: nil, per_page: nil, search: "", sort_by: [:title, :asc], filter: "unread"})

        csv << [
          user.name,
          user.email,
          user.home_email,
          comp_all_paths_hash[u_comp[0]],
          unread_docs.pluck(:title).join(", "),
          (user.active ? "Yes" : "No"),
          BaseService.time_formated(comp, user.created_at)
        ]
      end
    end

    {
      file: file,
      name: (user_ids != "all" ? "Selected Users.csv" : "Users.csv")
    }
  end

  ##
  # Query notification of a user in a company
  # - Only show need_approver, document_to_approver type for Advanced or Hybrid system
  ##
  def notification_query(comp)
    query = {company_id: comp.id}

    unless comp.show_admin_attentions
      query[:type.nin] = [ Notification::TYPES[:document_to_approve][:code], 
        Notification::TYPES[:need_approver][:code] ]
    end

    query
  end

  ##
  # Get unread notifications of a user in company
  ##
  def unread_notifications(comp)
    query = notification_query(comp)
    query[:status] = Notification::UNREAD_STATUS

    notifications.where(query)
  end

  ##
  # Get notifications of a user in company
  ##
  def get_notifications(comp)
    query = notification_query(comp)

    notifications.where(query)
  end

  ##
  # Get logs of user in a company
  ##
  def logs(company)
    activity_logs.all.with(collection: "#{company.id}_activity_logs")
  end

  ##
  # Get target logs of user in a company
  ##
  def target_logs(company)
    target_activity_logs.all.with(collection: "#{company.id}_activity_logs")
  end

  ##
  # create logs of user in a company
  # log_hash = {target_document_id: doc.id, action: ActivityLog::ACTIONS[:unfavourite_document]}
  ##
  def create_logs(company, log_hash)
    log_hash[:user_id] = self.id

    ActivityLog.with(collection: "#{company.id}_activity_logs").create(log_hash)
  end

  ##
  # Get documents of user in a company
  ##
  def company_documents(company)
    user_documents.all.with(collection: "#{company.id}_user_documents")
  end

  ##
  # create user_document of user and document in a company
  # hash = {document_id, is_accountable, is_favourited, is_read}
  ##
  def create_user_document(company, hash)
    hash[:user_id] = self.id
    
    if self.favourite_document_ids.include?(hash[:document_id])
      hash[:is_favourited] = true
    end

    if self.read_document_ids.include?(hash[:document_id])
      hash[:is_read] = true
    end

    u_doc = company_documents(company).where(document_id: hash[:document_id])

    if u_doc.count > 0
      hash[:updated_at] = Time.now.utc
      u_doc.update_all(hash)
    else
      UserDocument.with(collection: "#{company.id}_user_documents").create(hash)
    end
  end

  ##
  # Get list of company_id that user can see the report (for Webservice)
  ##
  def can_see_report_of_company_ids
    comp_ids = []
    if self.user_companies_info
      self.user_companies_info.each do |comp_id, u_comp|
        if u_comp["is_supervisor"]
          comp_ids << comp_id
        end
      end
    end

    comp_ids.join(",")
  end

  ##
  # true If there is as least a company that user have report permission 
  # else false
  ##
  def can_see_report_ws
    if self.user_companies_info
      self.user_companies_info.each do |comp_id, u_comp|
        return true if u_comp["is_supervisor"]
      end
    end

    false
  end
end
