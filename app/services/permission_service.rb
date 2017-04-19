class PermissionService < BaseService
  
  ALIAS_ACTIONS = {
    index: :read,
    show: :read,
    edit: :update,
    new: :create,

    setup: :update,
    check_login_before: :read,
    change_company_view: :update,
    profile: :update,
    update_path: :update,
    export_csv: :read,
    approve: :update,
    to_approve: :update,

    download_pdf: :read,
    update_batch: :update,

    structure: :organisation_structure,
    add_org_node: :organisation_structure,
    update_org_node: :organisation_structure,
    load_childs_of_org_node: :compliance,
    preview_company_structure: :organisation_structure,
    replicate_accountable_documents: :organisation_structure,
    compliance: :compliance,

    create_category: :create,
    update_category: :update,
    export_csv: :read,
    mark_as_read: :read,
    favourite: :read,
    update_name: :update,
    update_paths: :update,
    create_private_document: :create,
    logs: :read,
    favourite_docs: :read
  }

  ##
  # Check Current user has permission to do action with target object
  ##
  def self.has_permission(action, user, company, target_object)
    # puts "------has_permission-------"
    # puts target_object.inspect
    begin
      return true if user.admin
      
      alias_action = ALIAS_ACTIONS[action] || action
      target_class = target_object.try(:class)

      #There is also a super help desk user, who can do the same as the super user, but can not create companies
      if user.super_help_desk_user
        return alias_action != :create if target_class == Company

        return true
      end

      #User edit their info
      return true if (target_class == User && user.id == target_object.id && action == :profile)

      u_comp = user.user_company(company, true)
      return false unless user_comp_perm = user.comp_permission(company, u_comp, true)

      #Company
      if target_class == Company
        if alias_action == :organisation_structure
          return user_comp_perm[:can_edit_organisation_structure]
        end

        if alias_action == :compliance
          return u_comp["user_type"] != Permission::STANDARD_PERMISSIONS[:standard_user][:code]
        end

        if action == :generate_invoice
          return false
        end

        if action == :load_company_structure_table
          return can_load_company_structure_table(user, company, u_comp)
        end

        return user_comp_perm[:view_edit_company_billing_info_data_usage]
      end

      #only the Super User / Help desk user can read/create/update the permissions
      if target_class == Permission
        return false
      end
      
      if target_class == Document
        return true if action == :create_private_document

        #Only person that have can_make_document_restricted permission can make document is restricted
        if target_object.restricted_changed? && (target_object.restricted || target_object.restricted_was) && 
          (alias_action == :create || (alias_action == :update && action != :edit))

          return user_comp_perm.can_make_document_restricted
        end

        if target_object.is_private
          return user.private_doc?(target_object)
        end

        can_add_edit_doc = user_comp_perm[:add_edit_documents] || false

        if can_add_edit_doc && action != :approve && action != :to_approve && alias_action != :destroy
          return true
        end

        if action == :index || action == :export_csv
          return true
          
        elsif alias_action == :read
          return false if target_object.is_inactive

          # - Approval documents that are "to be approved" if not restricted are findable 
          #     (appear in search, it's All category, All) as non-accountable
          # - 
          if target_object.restricted
            return target_object.belongs_to_paths.include?(u_comp["company_path_ids"])
          end

          return true

        elsif alias_action == :destroy
          return user.private_doc?(target_object)

        elsif action == :approve || action == :to_approve || action == :approval_logs
          return false unless u_comp["is_approver"]

          return can_approve_document(user, company, target_object, u_comp)

        elsif action == :update_paths || action == :edit || action == :update
          return can_bulk_assign_documents(user, company, u_comp)

        end

        return can_add_edit_doc

      elsif target_class == User
        if action == :index
          return true if has_perm_see_users(user, company)
        elsif alias_action == :read
          return true if has_perm_add_edit_user(user, company, nil)
        elsif action == :new
          return has_perm_add_edit_user(user, company, nil)         
        end

        return has_perm_add_edit_user(user, company, target_object)
      end
    rescue Exception => e
      puts "---PermissionService.has_permission---"
      puts e
    end

    false
  end

  def self.has_perm_add_edit_user(user, company, target_user = nil, type = nil)
    return true if user.admin? || user.super_help_desk_user?

    return false unless user_comp_perm = user.comp_permission(company, nil, true)

    if target_user
      if target_user_comp = target_user.user_company(company, true)
        type = target_user_comp["user_type"] || "standard_user"
      else
        type = ""
      end

      user_comp_perm["add_edit_#{type}".to_sym] rescue false
    elsif type
      user_comp_perm["add_edit_#{type}".to_sym] rescue false
    else
      Permission::STANDARD_PERMISSIONS.keys.each do |key|
        if user_comp_perm["add_edit_#{key}".to_sym]
          return true
        end
      end
      false
    end
  end

  ##
  # Check user can see users list or not
  ##
  def self.has_perm_see_users(user, company)
    return true if user.admin? || user.super_help_desk_user?

    return true if has_perm_add_edit_user(user, company)

    u_comp = user.user_company(company, true)

    return (u_comp && u_comp["is_supervisor"])
  end

  ##
  # Check user have permission add/edit document or not
  ##
  def self.can_add_edit_document(user, company, u_comp = nil)
    return true if user.admin? || user.super_help_desk_user?

    return false unless user_comp_perm = user.comp_permission(company, u_comp, true)

    user_comp_perm[:add_edit_documents] || false
  end

  ##
  # Check user can make document is restricted or not
  ##
  def self.can_make_document_restricted(user, company, u_comp = nil)
    return true if user.admin? || user.super_help_desk_user?

    return false unless user_comp_perm = user.comp_permission(company, u_comp, true)

    user_comp_perm[:can_make_document_restricted] || false
  end

  ##
  # Check user can do bulk assign documents
  ##
  def self.can_bulk_assign_documents(user, company, u_comp = nil)
    return true if user.admin? || user.super_help_desk_user?

    return false unless user_comp_perm = user.comp_permission(company, u_comp, true)

    is_approver = user_comp_perm.is_approval_user || user_comp_perm.user_type == Permission::STANDARD_PERMISSIONS[:approver_user][:code]

    is_approver || user_comp_perm[:add_edit_documents] || false
  end

  ##
  # Return available areas that user can do bulk assign documents
  # ["supervisor_path_ids"]
  ##
  def self.available_areas_for_bulk_assign_documents(user, company, u_comp = nil)
    return company.all_paths_hash.keys if user.admin? || user.super_help_desk_user?

    u_comp ||= user.user_company(company, true)
    user_comp_perm = user.comp_permission(company, u_comp, true)

    return company.all_paths_hash.keys if user_comp_perm && user_comp_perm[:add_edit_documents]
    return [] unless u_comp["is_approver"]

    paths = (u_comp["approver_path_ids"] || [])
    if u_comp["is_supervisor"]
      paths.concat(u_comp["supervisor_path_ids"] || [])
    end

    paths.uniq!
    paths
  end

  ##
  # The permissions available are limited to the permissions that the user editing this already has. (when update user permissions)
  # Notice:
  # - If a user has “Edit Supervisor” or “Edit Approver” permissions, they can by default be allowed to assign the “Is approver” and “Is Supervisor” permissions.
  ##
  def self.available_perms(user, company)
    all_perms = Permission::RULES.keys
    if company.is_standard?
      all_perms.delete(:is_approval_user)
      all_perms.delete(:add_edit_approver_user)
    end

    return all_perms if user.admin? || user.super_help_desk_user?

    return [] unless user_comp_perm = user.comp_permission(company, nil, true)

    perms = []
    all_perms.each do |key|
      perms << key if user_comp_perm[key]
    end

    if !company.is_standard? && user_comp_perm[:add_edit_approver_user]
      perms << :is_approval_user
    end

    if user_comp_perm[:add_edit_supervisor_user]
      perms << :is_supervisor_user
    end

    perms.uniq!

    perms
  end


  ##
  # Get list of logs type that user can see
  ##
  def self.available_logs_type(user, company)
    all_types = ActivityLog::ACTIONS.values

    return all_types if user.admin? || user.super_help_desk_user?

    u_comp = user.user_company(company)
    u_comp_perm = u_comp.try(:permission)

    return [] if u_comp.blank? || u_comp_perm.blank?
    return all_types if u_comp.is_company_representative_user

    data = []

    rules = {
      add_edit_documents: ActivityLog::DOC_LOG_TYPES,
      view_all_user_read_receipt_reports: ["updated_report"],
      view_all_user_read_receipt_reports_under_assignment: ["updated_report"],
      view_edit_company_billing_info_data_usage: ActivityLog::COMPANY_LOG_TYPES,
      add_edit_company_representative_user: ActivityLog::COMPANY_LOG_TYPES,
      add_edit_admin_user: ActivityLog::USER_LOG_TYPES,
      add_edit_approver_user: ActivityLog::USER_LOG_TYPES,
      add_edit_supervisor_user: ActivityLog::USER_LOG_TYPES,
      add_edit_standard_user: ActivityLog::USER_LOG_TYPES,
      add_edit_document_control_admin_user: ActivityLog::USER_LOG_TYPES,
      add_edit_document_control_standard_user: ActivityLog::USER_LOG_TYPES,
      is_approval_user: ActivityLog::DOC_LOG_TYPES,
      can_make_document_restricted: ActivityLog::DOC_LOG_TYPES,
      can_edit_organisation_structure: ["created_organisation_structure", "updated_organisation_structure"]
    }

    rules.each do |key, value|
      if u_comp_perm[key]
        data.concat(value)
      end
    end

    data.uniq!

    data
  end

  ##
  # Get all user types that current user can edit
  # @return {Array} ["standard_user", "admin_user" .. ]
  ##
  def self.can_edit_user_types(current_user, comp, u_comp = nil, user_comp_perm = nil)
    has_perm = nil

    if current_user.admin? || current_user.super_help_desk_user?
      has_perm = true 
    else
      u_comp ||= current_user.user_company(comp)
      user_comp_perm ||= u_comp.try(:permission)

      if u_comp.nil? || user_comp_perm.nil?
        has_perm = false
      end
    end

    can_edit_user_types = []
    Permission::STANDARD_PERMISSIONS.keys.each do |key|
      u_type = Permission::STANDARD_PERMISSIONS[key][:code]

      can_edit_user_types << u_type if (has_perm || (user_comp_perm && user_comp_perm["add_edit_#{u_type}".to_sym]))
    end

    can_edit_user_types -= ["approver_user"] if comp.is_standard?

    can_edit_user_types
  end

  ##
  # Get viewable user ids
  ##
  def self.viewable_user_ids(current_user, comp, u_comp = nil, user_comp_perm = nil)
    u_comp ||= current_user.user_company(comp, true)
    user_comp_perm ||= u_comp.try(:permission)

    can_edit_u_types = can_edit_user_types(current_user, comp, u_comp, user_comp_perm)

    if u_comp && u_comp["is_supervisor"] && !u_comp["supervisor_path_ids"].blank?
      comp.user_companies.any_of({:company_path_ids.in => u_comp["supervisor_path_ids"]}, {:user_type.in => can_edit_u_types}).pluck(:user_id)
    else
      comp.user_companies.where(:user_type.in => can_edit_u_types).pluck(:user_id)
    end
  end

  ##
  # Check User can see report in a company or not
  # only user have report permission (view_all_user_read_receipt_reports | view_all_user_read_receipt_reports_under_assignment) can see it
  ##
  def self.can_see_report(current_user, comp, u_comp = nil, user_comp_perm = nil)
    return true if current_user.admin? || current_user.super_help_desk_user?

    u_comp ||= current_user.user_company(comp, true)

    u_comp && (u_comp[:can_see_report] || u_comp["can_see_report"])
  end

  ##
  # check user can approve document or not
  ##
  def self.can_approve_document(current_user, comp, document, u_comp = nil)
    return false if comp.is_standard? || !document.need_approval

    return true if current_user.admin? || current_user.super_help_desk_user?

    u_comp ||= current_user.user_company(comp, true)

    document.can_approve_by?(current_user, u_comp )
  end

  ##
  # Check user can load_company_structure_table
  # User can when:
  #   - Super Admin/ Super help desk user
  #   - user can add/edit user
  #   - user can do bulk assign document / add/edit document
  #   - user can approve document
  ##
  def self.can_load_company_structure_table(user, company, u_comp = nil)
    return true if user.admin? || user.super_help_desk_user?

    u_comp ||= user.user_company(company, true)

    has_perm_add_edit_user(user, company) || can_add_edit_document(user, company, u_comp) || u_comp["is_approver"]
  end

  ##
  # Area that approver can approve a document
  ##
  def self.approver_can_approve_document_for_areas(user, company, document)
    return (document.try(:not_approved_paths) || []) if user.admin? || user.super_help_desk_user?

    u_comp = user.user_company(company, true)

    u_comp["approver_path_ids"] & (document.try(:not_approved_paths) || [])
  end

  # Check user can edit company type
  # Super Admin, super help desk user and Company Rep can have this permission
  ##
  def self.can_edit_company_type(user, company, u_comp = nil)
    return true if user.admin? || user.super_help_desk_user?

    return false unless user_comp_perm = user.comp_permission(company, u_comp, true)

    user_comp_perm.user_type == Permission::STANDARD_PERMISSIONS[:company_representative_user][:code]
  end

  ##
  # This will be used if Admin/Super Admin user wish to quickly see which users currently supervise for/approve for a section in the organisation.
  ##
  def self.has_perm_see_supervisors_approvers(user, company)
    return true if user.admin? || user.super_help_desk_user?

    u_comp = user.user_company(company, true)

    u_comp && (u_comp["user_type"] == Permission::STANDARD_PERMISSIONS[:company_representative_user][:code] || u_comp["user_type"] == Permission::STANDARD_PERMISSIONS[:admin_user][:code])
  end

  ##
  #
  ##
  def self.can_remotely_wipe_device(company, current_user, user)
    return true if current_user.admin? || current_user.super_help_desk_user?

    return true if current_user.id == user.id

    u_comp = current_user.user_company(company, true)
    u_comp["user_type"] == Permission::STANDARD_PERMISSIONS[:company_representative_user][:code] || u_comp["user_type"] == Permission::STANDARD_PERMISSIONS[:admin_user][:code]
  end
end