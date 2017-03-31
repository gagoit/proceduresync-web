class UserService < BaseService

  def self.staff_with_outstanding_documents(user, company, page: 1, per_page: 50)
    # Rails.cache.fetch("#{company.id}-#{user.id}-staff-with-outstanding-documents", :expires_in => 1.hours) do
      page = page.to_i
      page = 1 if page < 1
      per_page = per_page.to_i
      result = []

      u_comp = user.user_company(company, true)
      user_comp_perm = user.comp_permission(company, u_comp, true)
      users_info = []

      user_ids = ReportService.report_ws_user_ids(user, company) - [user.id]

      return [] if user_ids.blank?

      users_info = company.user_companies.where(:user_id.in => user_ids).order([:name, :asc]).page(page).per(per_page).pluck(:user_id, :user_type, :company_path_ids)

      users_info_hash = {}
      viewable_users_company_path_info = {}
      users_info.each do |e|
        users_info_hash[e[0]] = {
          user_type: e[1],
          company_path_ids: e[2]
        }

        unless viewable_users_company_path_info[e[2]]
          viewable_users_company_path_info[e[2]] = Document.accountable_documents_for_area(company, e[2]).pluck(:id)
        end
      end

      user_ids = users_info_hash.keys
      return [] if user_ids.blank?

      can_edit_user_types = PermissionService.can_edit_user_types(user, company, u_comp, user_comp_perm)
      users = company.users.where(:id.in => user_ids)

      users.each do |u|
        next unless (accountable_doc_ids = viewable_users_company_path_info[users_info_hash[u.id][:company_path_ids]] rescue nil)

        u_data = {
          unread_num: (accountable_doc_ids - u.read_document_ids - u.private_document_ids).length,
          id: u.id,
          name: u.name
        }

        if u.admin || u.super_help_desk_user
          u_data[:unread_num] = u.docs(company, "unread")[:unread_number]
        end

        if has_perm = can_edit_user_types.include?(users_info_hash[u.id][:user_type])
          u_data[:href] = Rails.application.routes.url_helpers.edit_user_path(id: u_data[:id])
          u_data[:a_class] = "has-perm"
        else
          u_data[:href] = "javascript:;"
          u_data[:a_class] = "has-no-perm"
        end

        u_data[:has_perm] = (has_perm || user.id == u.id)

        result << u_data if u_data[:unread_num] > 0
      end

      result
    # end
  end

  ##
  # Accountable categories are the documents categories that are assigned to this user.
  ##
  def self.accountable_categories(user, company)
    u_comp = user.user_company(company, true)

    docs = user.assigned_docs(company, u_comp, [:category_name, :asc])

    docs.pluck(:category_id, :category_name).uniq
  end

  ##
  # Any: Can see documents that are: Active && (Accountable || (Not Accountable && Not Restricted) and in that category.
  # Add / Edit Documents:  All documents for that category except inactive.
  ##
  def self.all_document_categories(user, company)
    docs, total_count = Document.get_all(user, company, {page: nil, per_page: nil, search: "", sort_by: [[:category_name, :asc]], filter: "all", category_id: nil, types: "all"})

    docs.pluck(:category_id, :category_name).uniq
  end

  ##
  # Create users for a company from csv file
  # name
  # area e.g. Rail > Cape Lambert > Train Driver
  # email
  # phone
  # supervisor area e.g. Rail > Cape Lambert > Train Driver
  # approver area e.g. Rail > Cape Lambert > Train Driver
  # permission e.g. “Admin”, “Supervisor”, “Approver”, “Standard”
  ##
  def self.bulk_create(company, import_user, user )
    return unless import_user.file_file_name

    result = {
      lines: 0,
      users: 0,
      invalid_users: [],
      valid_users: []
    }

    comp_all_paths = company.all_paths_hash #{id => name}
    comp_all_path_names = comp_all_paths.invert #{name => id}
    comp_all_path_names_with_comp_node = {}
    comp_all_paths.each do |key, value|
      value_tmp = "#{company.name}#{Company::NODE_SEPARATOR}#{value}"
      comp_all_path_names_with_comp_node[value_tmp] = key
    end

    valid_perms = {}
    perms = {} #{code => id}
    company.permissions.standard.pluck(:id, :name, :code).each do |perm|
      perms[perm[2]] = perm[0]
    end

    Permission::STANDARD_PERMISSIONS.each do |key, value|
      valid_perms[value[:name]] = {code: value[:code], id: perms[value[:code]]}
    end

    new_emails = []

    # Get path ids from path names
    get_path_ids = lambda { |path_names|
      if path_names.include?(";")
        path_names.split(";").map do |e|
          get_path_ids.call(e)
        end
      else
        comp_all_path_names[path_names] || comp_all_path_names_with_comp_node[path_names]
      end
    }

    #Name, Belongs To, Email, Phone, supervisor area, approver area, permission
    CSV.foreach(open(import_user.file.url), { :col_sep => ',' }) do |row|
      result[:lines] += 1
      check = {}

      is_approver = false
      is_supervisor = false

      user_hash = {
        name: row[0].to_s.strip,
        belongs_to_path_names: row[1].to_s.strip,
        email: row[2].to_s.strip.downcase,
        phone: row[3].to_s.strip,
        supervisor_area_names: row[4].to_s.strip,
        approver_area_names: row[5].to_s.strip,
        permission: row[6].to_s.strip
      }

      blank_row = true
      [:name, :belongs_to_path_names, :email, :permission].each do |key|
        unless user_hash[key].blank?
          blank_row = false
          break
        end
      end

      if blank_row
        result[:lines] -= 1
        next
      end

      if new_emails.include?(user_hash[:email])
        check[:email] = {valid: false, message: I18n.t("user.import.errors.email")}

        result[:invalid_users] << user_hash.merge!({result_check: check})
        next
      end
      
      new_emails << user_hash[:email]
      check[:email] = {valid: true}

      user_hash[:belongs_to_path_names] = normalize_company_paths(user_hash[:belongs_to_path_names])
      if user_hash[:belongs_to_paths] = get_path_ids.call(user_hash[:belongs_to_path_names])
        check[:belongs_to_paths] = {valid: true}
      else
        check[:belongs_to_paths] = {valid: false, 
          message: I18n.t("user.import.errors.belongs_to_paths"), value: user_hash[:belongs_to_path_names]}
      end

      #check permission
      user_hash[:permission] = user_hash[:permission].split(" ").join(" ")
      if perm = valid_perms[user_hash[:permission]]
        check[:permission] = {valid: true}
        user_hash[:permission_id] = perm[:id]
      else
        check[:permission] = {valid: false, 
          message: I18n.t("user.import.errors.permission"), value: user_hash[:permission]}
      end

      if user_hash[:permission] == Permission::STANDARD_PERMISSIONS[:approver_user][:name]
        is_approver = true
      elsif user_hash[:permission] == Permission::STANDARD_PERMISSIONS[:supervisor_user][:name]
        is_supervisor = true
      end

      if is_supervisor
        user_hash[:supervisor_area_names] = normalize_company_paths(user_hash[:supervisor_area_names])
        if (user_hash[:supervisor_area] = get_path_ids.call(user_hash[:supervisor_area_names])) && !user_hash[:supervisor_area].blank?
          check[:supervisor_area] = {valid: true}
        else
          check[:supervisor_area] = {valid: false, 
            message: I18n.t("user.import.errors.supervisor_area"), value: user_hash[:supervisor_area_names]}
        end
      end

      if is_approver && !company.is_standard?
        user_hash[:approver_area_names] = normalize_company_paths(user_hash[:approver_area_names])
        if (user_hash[:approver_area] = get_path_ids.call(user_hash[:approver_area_names])) && !user_hash[:approver_area].blank?
          check[:approver_area] = {valid: true}
        else
          check[:approver_area] = {valid: false, 
            message: I18n.t("user.import.errors.approver_area"), value: user_hash[:approver_area_names]}
        end
      elsif is_approver
        check[:approver_area] = {valid: false, 
            message: I18n.t("user.import.errors.company_have_no_approver_permision"), value: user_hash[:approver_area_names]}
      end

      User.without_callback(:save, :after) do
        if user = User.where(email_downcase: user_hash[:email].downcase).first
        else
          user = User.new()
        end

        user.name = user_hash[:name]
        user.email = user_hash[:email]
        user.phone = user_hash[:phone]
        user.company_ids = (user.company_ids || []) + [company.id]
        user.company_ids.uniq!
        user.updated_by_admin = true
        user.active = true
        user.save

        if user.valid?
          CampaignService.delay.update_subscriber(user) 

          u_comp_hash = {permission_id: user_hash[:permission_id], approver_path_ids: [], supervisor_path_ids: [], 
            company_path_ids: user_hash[:belongs_to_paths]}
          if is_approver
            u_comp_hash[:approver_path_ids] = user_hash[:approver_area].is_a?(Array) ? user_hash[:approver_area] : [user_hash[:approver_area]]
          elsif is_supervisor
            u_comp_hash[:supervisor_path_ids] = user_hash[:supervisor_area].is_a?(Array) ? user_hash[:supervisor_area] : [user_hash[:supervisor_area]]
          end

          user.add_company(company, u_comp_hash)
        end
      end

      result[:valid_users] << user_hash.merge({id: user.id})

    end

    result[:users] = result[:lines]

    import_user.status = "done"
    import_user.result = result
    import_user.save

    import_user
  end

  def self.normalize_company_paths(paths)
    paths.split(Company::NODE_SEPARATOR).map { |e| e.strip }.join(Company::NODE_SEPARATOR)
  end

  ##
  # Remove device of user in Pusher 
  # only remove if device is belongs to this user
  ##
  def self.remove_user_device_in_pusher(user, push_token, app_access_token)
    if user.devices.where(app_access_token: app_access_token, token: push_token).first
      NotificationService.delay(queue: "notification_and_convert_doc").update_tags_in_device(user, push_token, app_access_token, false)
    end
  end

  ##
  # Update user_documents table: for accountable docs
  ##
  def self.update_user_documents(options = {})
    company = options[:company]

    return if company.blank?

    if user = options[:user]
      update_user_documents_when_user_change(options)
      
      user.update_docs_count(company)

    elsif document = options[:document]
      update_user_documents_when_document_change(options)
    end
  end

  ##
  # When user is changed, need to update the user-document relationship
  ## 
  def self.update_user_documents_when_user_change(options = {})
    company = options[:company]
    user = options[:user]

    return if company.blank? || user.blank?

    user.reload
    sync_doc_ids = user.new_docs(company).pluck(:id)
    already_synced_doc_ids = user.company_documents(company).accountable.pluck(:document_id)
    new_sync_doc_ids = sync_doc_ids - already_synced_doc_ids

    user.company_documents(company).where(:document_id.nin => sync_doc_ids).update_all({updated_at: Time.now.utc, is_accountable: false})

    new_sync_doc_ids.each do |doc_id|
      u_doc = user.create_user_document(company, {document_id: doc_id})
    end

    user.company_documents(company).where(:document_id.in => sync_doc_ids).update_all({is_accountable: true, updated_at: Time.now.utc})
    
    NotificationService.delay(queue: "notification_and_convert_doc").add_accountable([user.id], new_sync_doc_ids) unless new_sync_doc_ids.blank?

    not_accountable_doc_ids = user.company_documents(company).where(:document_id.nin => sync_doc_ids).pluck(:document_id)
    NotificationService.delay(queue: "notification_and_convert_doc").remove_accountable([user.id], not_accountable_doc_ids) unless not_accountable_doc_ids.blank?

    ## Create notification in web admin for unread accountable documents
    unread_accountable_doc_ids = user.assigned_docs(company).where(:id.nin => user.read_document_ids).pluck(:id)
    unread_accountable_doc_ids.each do |d_id|
      noti = Notification.find_or_initialize_by({user_id: user.id, company_id: company.id, 
        type: Notification::TYPES[:unread_document][:code], document_id: d_id})

      noti.created_at = Time.now.utc
      noti.status = Notification::UNREAD_STATUS
      noti.save
    end
  end

  ##
  # When document is changed, need to update the user-document relationship
  ##
  def self.update_user_documents_when_document_change(options = {})
    company = options[:company]
    document = options[:document]

    return if company.blank? || document.blank?

    document.reload
    available_user_ids = document.available_for_user_ids({accept_inactive: true})
    already_avai_user_ids = document.company_users(company).accountable.pluck(:user_id)
    new_avai_user_ids = available_user_ids - already_avai_user_ids

    document.company_users(company).where(:user_id.nin => available_user_ids).update_all({updated_at: Time.now.utc, is_accountable: false})

    new_avai_user_ids.each do |user_id|
      u_doc = document.create_user_document(company, {user_id: user_id})
    end

    company.user_companies.where(:user_id.in => (available_user_ids + already_avai_user_ids)).update_all(need_update_docs_count: true)
    # User.delay.update_docs_count

    document.company_users(company).where(:user_id.in => available_user_ids).update_all({is_accountable: true, updated_at: Time.now.utc})

    if document.is_inactive
      NotificationService.delay(queue: "notification_and_convert_doc").document_is_invalid(document)
      User.delay(queue: "update_data").remove_invalid_docs(company.user_ids, [document.id])
      return
    elsif !document.effective
      NotificationService.delay(queue: "notification_and_convert_doc").documents_have_changed_meta_data(document.company_users(company).pluck(:user_id), [document.id])
      return
    end

    not_accountable_user_ids = document.company_users(company).where(is_accountable: false).pluck(:user_id)

    NotificationService.delay(queue: "notification_and_convert_doc").remove_accountable(not_accountable_user_ids, [document.id]) unless not_accountable_user_ids.blank?
    
    if options[:new_version]
      NotificationService.delay(queue: "notification_and_convert_doc", run_at: (document.effective_time.try(:utc) || Time.now.utc)).document_is_created(document, available_user_ids)
    elsif options[:change_area]
      NotificationService.delay(queue: "notification_and_convert_doc", run_at: (document.effective_time.try(:utc) || Time.now.utc)).document_is_created(document, new_avai_user_ids)
      NotificationService.delay(queue: "notification_and_convert_doc").documents_have_changed_meta_data(already_avai_user_ids, [document.id])
    else
      NotificationService.delay(queue: "notification_and_convert_doc").documents_have_changed_meta_data(available_user_ids, [document.id])
    end
  
    ## Create notification in web admin for unread accountable documents
    DocumentService.create_unread_doc_noti_in_web_admin(
        document, 
        {
          new_version: options[:new_version],
          new_avai_user_ids: new_avai_user_ids
        }
      )
  end

  ##
  # Update user_documents table when a user favourite/unfavourite/read a doc (accountable or none-accountable)
  # @params:
  #   options = {
  #     user:
  #     company:
  #     document:
  #   }
  ##
  def self.update_user_documents_when_status_change(options = {})
    company = options[:company]
    user = options[:user]
    document = options[:document]

    return unless company && user && document
    user.reload
    document.reload

    u_comp = user.user_company(company, true)
    u_doc = user.company_documents(company).where({document_id: document.id})
    is_favourited = user.favourited_doc?(document)
    is_accountable = document.private_for_id == user.id || document.approved_paths.include?(u_comp["company_path_ids"])

    if u_doc.count == 0
      user.create_user_document(company, {document_id: document.id, is_favourited: is_favourited, 
        is_accountable: is_accountable})
    else
      u_doc.update_all({is_favourited: is_favourited, is_accountable: is_accountable, updated_at: Time.now.utc})
    end

    # user.user_companies.where(:company_id => company.id).update_all(need_update_docs_count: true)
    user.update_docs_count(company)

    if is_accountable || is_favourited
      NotificationService.delay(queue: "notification_and_convert_doc").documents_have_changed_meta_data([user.id], [document.id])
    else
      NotificationService.delay(queue: "notification_and_convert_doc").remove_accountable([user.id], [document.id])
    end
  end

  ##
  # Get Admin related with current user in company
  # Note:
  #   - Document Control Admin Users should not have regular "Admin Users" show on their dashboard 
  #     as "Admin Contacts".  Only other Document Control Admins should be displayed as Admin Contact
  #   - Document Control Standard Users should not have regular "Admin Users" show on their dashboard 
  #     as "Admin Contacts".  Only Document Control Admins should be displayed as Admin Contact
  #   - Other will show regular "Admin Users"
  ##
  def self.get_admins(user, company, u_comp = nil)
    u_comp ||= user.user_company(company, true)

    admin_type = "regular_admin"
    if u_comp["user_type"] == Permission::STANDARD_PERMISSIONS[:document_control_admin_user][:code] || 
        u_comp["user_type"] ==  Permission::STANDARD_PERMISSIONS[:document_control_standard_user][:code]

      admin_ids = company.user_companies.document_control_admins.pluck(:user_id)
      admin_type = "document_control_admin"
    else
      admin_ids = company.user_companies.admins.pluck(:user_id)
    end
    admin_ids -= [user.id]

    admins = User.where(:id.in => admin_ids).active.pluck(:id, :name, :email, :phone).map { |e| 
              e[3] ||= ""
              e << admin_type 
            }
  end


  ##
  # User with Approver permissions: Have a dashboard widget which shows Areas they approve for, 
  # that do not have any accountable documents. Label "Areas without Accountable Documents" 
  ##
  def self.areas_without_accountable_documents(user, company)
    u_comp = user.user_company(company, true)
    approver_path_ids = u_comp["approver_path_ids"]

    if user.admin || user.super_help_desk_user
      approver_path_ids = company.all_paths_hash.keys
    else
      if approver_path_ids.blank? || !u_comp["is_approver"]
        return []
      end
    end

    accountable_docs_in_paths = company.documents.active.public_all.effective.where({:approved_paths.in => approver_path_ids})
    paths_has_accountable_docs = accountable_docs_in_paths.pluck(:approved_paths)
    paths_has_no_accountable_docs = approver_path_ids

    paths_has_accountable_docs.each do |paths|
      paths_has_no_accountable_docs = paths_has_no_accountable_docs - paths
    end

    paths_has_no_accountable_docs
  end
end
