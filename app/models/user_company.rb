class UserCompany
  include Mongoid::Document
  include Mongoid::Timestamps

  APPROVAL_EMAIL_SETTINGS = {
    no_email: "no_email",
    email_instantly: "email_instantly",
    email_daily: "email_daily"
  }

  belongs_to :user
  belongs_to :company
  belongs_to :permission

  field :company_path_ids, type: String, default: ""
  field :approver_path_ids, type: Array, default: []
  field :supervisor_path_ids, type: Array, default: []
  field :show_admin_detail, type: Boolean, default: false

  field :user_type, type: String, default: Permission::STANDARD_PERMISSIONS[:standard_user][:code]

  field :is_custom, type: Boolean, default: false
  field :is_approver, type: Boolean, default: false
  field :is_supervisor, type: Boolean, default: false

  field :can_see_report, type: Boolean, default: false

  field :last_sync, :type => Time

  field :approval_email_settings, type: String, default: APPROVAL_EMAIL_SETTINGS[:email_instantly]

  field :active, type: Boolean, default: true

  field :unread_docs_count, type: Integer, default: 0      # This is a total of all documents the user has that are "Active" + "Accountable" + "Unread"
  field :accountable_docs_count, type: Integer, default: 0 # This is a total of all documents the user has that are "Active" + "Accountable" 

  field :need_update_docs_count, type: Boolean                  # When document has been changed, we need to update the cache (unread doc, accountable doc) for user

  index({user_id: 1, company_id: 1})

  index({company_id: 1})
  index({company_id: 1, user_type: 1})

  scope :by_company, ->(comp_id) {where(company_id: comp_id)}
  scope :approvers, -> {where(is_approver: true)}
  scope :admins, -> {where(:user_type.in => [Permission::STANDARD_PERMISSIONS[:company_representative_user][:code], 
    Permission::STANDARD_PERMISSIONS[:admin_user][:code]])}

  scope :document_control_admins, -> {where(:user_type => Permission::STANDARD_PERMISSIONS[:document_control_admin_user][:code])}

  scope :active, -> {where(active: true)}

  before_save do
    if permission_id_changed? || user_type.blank?
      if permission
        self.user_type = Permission::STANDARD_PERMISSIONS[permission.user_type.try(:to_sym)][:code] rescue Permission::STANDARD_PERMISSIONS[:standard_user][:code]

        self.is_custom = permission.is_custom
      else
        self.permission_id = company.permissions.where(:code => Permission::STANDARD_PERMISSIONS[:standard_user][:code]).first.try(:id)
        self.user_type = Permission::STANDARD_PERMISSIONS[:standard_user][:code]
      end
    end

    if permission
      self.is_approver = (permission.is_approval_user || user_type == Permission::STANDARD_PERMISSIONS[:approver_user][:code])
      self.is_supervisor = (permission.is_supervisor_user || user_type == Permission::STANDARD_PERMISSIONS[:supervisor_user][:code])

      self.approver_path_ids = [] unless self.is_approver 
      self.supervisor_path_ids = [] unless self.is_supervisor

      self.can_see_report = permission.view_all_user_read_receipt_reports || permission.view_all_user_read_receipt_reports_under_assignment
    end

    true
  end

  after_save do
    begin
      u_comp_hash = self.attributes.except("user_id", "_id", "permission_id", "company_id")
      u_comp_hash["id"] = self.id.to_s
      u_comp_hash["user_id"] = self.user_id.to_s
      u_comp_hash["permission_id"] = self.permission_id.to_s
      u_comp_hash["company_id"] = self.company_id.to_s
      user.user_companies_info[company_id.to_s] = u_comp_hash
      user.save(validate: false)
    rescue Exception => e
      BaseService.notify_or_ignore_error(Exception.new("#{e.message}: company_id #{company.try(:id)}, user_id #{user.try(:id)}"))
    end

    if company_path_ids_changed?
      NotificationService.delay.users_has_changed_company_path([user])

      UserService.delay.update_user_documents({user: user, company: company})
    elsif can_see_report_changed?
      NotificationService.delay.user_has_been_changed_report_permission(user)
    end

    if user_type_changed?
      CampaignService.delay.change_subscriber_list(user, CAMPAIGNS[:lists][user_type_was.to_s.to_sym], CAMPAIGNS[:lists][user_type.to_s.to_sym])
    end

    if (is_approver_changed? || user_type_changed?) && user_type_was.to_s.to_sym != :approver_user && user_type.to_s.to_sym != :approver_user
      old_list = new_list = CAMPAIGNS[:lists][:approver_user]

      if is_approver
        old_list = nil
      else
        new_list = nil
      end

      CampaignService.delay.change_subscriber_list(user, old_list, new_list)
    end

    if (is_supervisor_changed? || user_type_changed?) && user_type_was.to_s.to_sym != :supervisor_user && user_type.to_s.to_sym != :supervisor_user
      old_list = new_list = CAMPAIGNS[:lists][:supervisor_user]

      if is_supervisor
        old_list = nil
      else
        new_list = nil
      end

      CampaignService.delay.change_subscriber_list(user, old_list, new_list)
    end

    ## Remove Admin Attention in the area that user is set as approver
    if is_approver && company
      company.admin_attentions.where(:all_path_ids.in => approver_path_ids).destroy_all
    end
  end

  after_create do
    CampaignService.delay.create_subscriber(user, company)
  end

  def destroy
    if company && user
      CampaignService.delay.change_subscriber_list(user, company.campaign_list_id, nil)
      CampaignService.delay.change_subscriber_list(user, CAMPAIGNS[:lists][user_type.to_s.to_sym], nil)

      user.user_companies_info.delete(company_id.to_s)
      user.save(validate: false)
    end

    super
  end

  def is_company_representative_user
    user_type == Permission::STANDARD_PERMISSIONS[:company_representative_user][:code]
  end

  def is_standard_user
    user_type == Permission::STANDARD_PERMISSIONS[:standard_user][:code]
  end
end