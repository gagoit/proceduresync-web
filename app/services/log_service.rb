class LogService < BaseService

  def self.get_more_log_info(act, current_user, company, type = "user")
    i_hash = {}
    add_text = []
    actor = act.user
      
    if act.target_user_id
      i_hash[:user_name] = act.target_user.try(:name)

      #Show changed attributes
      i18n_scope = [:logs, :attributes, :user]
      
      add_text = format_changed_attributes(company, act, i18n_scope)
    elsif act.target_document_id
      i_hash[:doc_title] = act.target_document.try(:title)
      i_hash[:user_name] = actor.try(:name)
      i_hash[:version] = act.attrs_changes["version"] || ""

      if act.action == ActivityLog::ACTIONS[:updated_document]
        # unless act.attrs_changes["category_id"].blank?
        #   i_hash[:cate_name] = Category.where(id: act.attrs_changes["category_id"][1]).first.try(:name)

        #   add_text << I18n.t("logs.#{type}.change_category", i_hash)
        # end

        # if (!act.attrs_changes["active"].blank? && !act.attrs_changes["active"][1]) || 
        #   (!act.attrs_changes["expiry"].blank? && act.attrs_changes["expiry"][1].utc <= Time.now.utc)

        #   add_text << I18n.t("logs.#{type}.made_document_inactive", i_hash)
        # elsif (!act.attrs_changes["active"].blank? && act.attrs_changes["active"][1])
        #   add_text << I18n.t("logs.#{type}.made_document_active", i_hash)
        # end

        #Show changed attributes
        i18n_scope = [:logs, :attributes, :document]
        
        add_text.concat(format_changed_attributes(company, act, i18n_scope))
      end
    else
      i_hash[:user_name] = actor.try(:name)
      
      if act.attrs_changes["node_name"].is_a?(String)
        i_hash[:node_name] = "'#{act.attrs_changes["node_name"]}'"
        i_hash[:node_type] = company.try("#{act.attrs_changes["node_type"]}_label".to_sym) || act.attrs_changes["node_type"].titleize

      elsif act.attrs_changes["node_name"].is_a?(Array)
        i_hash[:node_name] = "'#{act.attrs_changes["node_name"][0]}' to '#{act.attrs_changes["node_name"][1]}'"
        i_hash[:node_type] = company.try("#{act.attrs_changes["node_type"]}_label".to_sym) || act.attrs_changes["node_type"].titleize
      end
        
      if act.attrs_changes["perm_name"]
        i_hash[:perm_name] = act.attrs_changes["perm_name"]

      elsif act.attrs_changes["permissions"]
        perms = []
        act.attrs_changes["permissions"].each do |perm_id, perm|
          perms << perm["name"]
        end
        i_hash[:perm_name] = perms.join(", ")
      end
    end

    return i_hash, add_text
  end

  def self.user_logs(user, current_user, company, page = 1, per_page = PER_PAGE)
    acts = user.logs(company).includes(:target_document, :target_user).order([:action_time, :desc]).page(page).per(per_page)

    return_data = {
      "aaData" => [],
      "iTotalDisplayRecords" => acts.length,
      "iTotalRecords" => acts.total_count
    }

    acts.each do |act|
      i_hash, add_text = get_more_log_info(act, current_user, company, "user")

      act_text = I18n.t("logs.user.#{act.action}", i_hash)
      act_text = "#{act_text} #{add_text.join(', ')}" if add_text.length > 0

      data = {
        action_time: BaseService.time_formated(company, act.action_time),
        log: act_text
      }

      return_data["aaData"] << data
    end

    return_data
  end

  def self.document_logs(current_user, company, document, page = 1, per_page = PER_PAGE)
    acts = document.logs.includes(:target_document, :target_user, :user).order([:action_time, :desc]).page(page).per(per_page)

    return_data = {
      "aaData" => [],
      "iTotalDisplayRecords" => acts.length,
      "iTotalRecords" => acts.total_count
    }

    acts.each do |act|
      i_hash, add_text = get_more_log_info(act, current_user, company, "document")

      user_url = ActionController::Base.helpers.link_to(i_hash[:user_name], (Rails.application.routes.url_helpers.users_path(search: i_hash[:user_name]) rescue ""), target: "_blank")

      act_text = I18n.t("logs.document.#{act.action}", i_hash)
      act_text = "#{act_text} #{add_text.join(', ')}" if add_text.length > 0

      data = {
        action_time: BaseService.time_formated(company, act.action_time),
        log: act_text,
        user_url: user_url,
        user_name: i_hash[:user_name]
      }

      return_data["aaData"] << data
    end

    return_data
  end

  ##
  # Get logs for whole company
  # For logs any time there is "Updated user.." or "Updated document.." 
  #   put "Changed document 'Document Name' category to 'Category Name', 
  #   title to 'New Document Name' and ID to 'doc001'.
  ##
  def self.company_logs(current_user, company, page, per_page, search)
    acts = company.logs.includes(:target_document, :target_user, :user).order([:action_time, :desc])

    logs_types = PermissionService.available_logs_type(current_user, company)
    acts = acts.any_of({:action.in => logs_types}, {user_id: current_user.id})

    search = search.to_s.strip

    unless search.blank?
      acts = acts.where(view_company_log: /#{search}/i)
    end
    # if search.blank?
      acts = acts.page(page).per(per_page)

      return_data = {
        "aaData" => [],
        "iTotalDisplayRecords" => acts.length,
        "iTotalRecords" => acts.total_count
      }
    #   search_parts = []
    # else
    #   return_data = {
    #     "aaData" => [],
    #     "iTotalDisplayRecords" => 0,
    #     "iTotalRecords" => 0
    #   }

    #   search_parts = search.downcase.split(" ").uniq
    # end

    #puts "logs_types: #{logs_types.join(' ')}"

    aaData = []
    acts.each do |act|
      actor = act.user
      i_hash, add_text = get_more_log_info(act, current_user, company, "company")

      user_url = ActionController::Base.helpers.link_to(actor.try(:name), (Rails.application.routes.url_helpers.users_path(search: actor.try(:name)) rescue ""), target: "_blank")

      act_text = I18n.t("logs.company.#{act.action}", i_hash)
      act_text = "#{act_text} #{add_text.join(', ')}" if add_text.length > 0

      data = {
        action_time: BaseService.time_formated(company, act.action_time),
        log: act_text,
        user_url: user_url,
        user_name: actor.try(:name)
      }

      #if search.blank?
        return_data["aaData"] << data
      #else
      #   search_parts.each do |e|
      #     if data[:action_time].downcase.index(e) || data[:log].downcase.index(e) || data[:user_name].to_s.downcase.index(e)
      #       aaData << data
      #       break
      #     end
      #   end
      # end
    end

    # unless search.blank?
    #   return_data["aaData"] = aaData[(page - 1)*per_page, per_page] || []
      
    #   return_data["iTotalDisplayRecords"] = aaData.length
    #   return_data["iTotalRecords"] = aaData.length
    # end

    return_data
  end

  ##
  # Format changed attributes
  # @params:
  #    company
  #    activity
  #    i18n_scope: 
  # @return:
  #    String:  title to 'New Document Name'
  ##
  def self.format_changed_attributes(company, activity, i18n_scope)
    add_text = []
    comp_all_paths = company.all_paths_hash #{id => name}
    permissions = company.permissions.pluck(:id, :name, :is_custom, :for_user_name, :for_user_id)
    permissions_hash = {}
    permissions.each do |perm|
      if perm[2] #is_custom
        permissions_hash[perm[0]] = perm[1].gsub("##{perm[4]}", "for #{perm[3]}")
      else
        permissions_hash[perm[0]] = perm[1]
      end
    end

    options = {
      comp_all_paths: comp_all_paths,
      permissions_hash: permissions_hash
    }

    except_fields = ["_keywords", "updated_at", "need_validate_required_fields", "updated_by_id",
      "utf8", "authenticity_token", "document", "format",
      "action", "controller", "id", "approved", "category_id", "need_approval", "approved_by_ids",
      "read_user_ids", "effective", "belongs_to_paths"]

    txt = "<ul>"

    activity.attrs_changes.each do |attr|
      next if except_fields.include?(attr[0].to_s)

      tmp = format_changed_attribute(company, attr[0], attr[1], i18n_scope, options)

      txt << "<li>#{tmp}</li>" unless tmp.blank?
    end

    txt << "</ul>"

    [txt]
  end

  ##
  # Format changed attribute
  # @params:
  #    company
  #    field
  #    changes: Array [old_value, new_value]
  #    i18n_scope: 
  #    options: {:comp_all_paths, :permissions_hash}
  # @return:
  #    String:  title to 'New Document Name'
  ##
  def self.format_changed_attribute(company, field, changes, i18n_scope, options)
    old_value = changes[0]
    new_value = 
      if changes.length > 1
        changes[1]
      else
        changes[0]
      end

    if new_value.is_a?Array
      if field == "approved_paths" && new_value.blank?
        return "#{I18n.t(:removed_accountabilities, scope: i18n_scope)}"
      end

      changed_value = new_value - (old_value || [])
    else
      changed_value = new_value
    end

    format_value_lambda = lambda { |value|
      if value.is_a?(Date)
        BaseService.time_formated(company, value, I18n.t("date.format"))
      elsif value.is_a?(Time)
        BaseService.time_formated(company, value)
      elsif value.is_a?Array
        txt = "<ul>"
        value.each do |e|
          txt << "<li>#{format_value_lambda.call(e)}</li>"
        end
        
        txt << "</ul>"

        txt
      elsif options[:comp_all_paths][value]
        options[:comp_all_paths][value]
      elsif field == "permission_id"
        options[:permissions_hash][value] || value
      elsif ["active", "restricted"].include?(field)
        I18n.t("boolean_values.#{value}")
      else 
        area_name(company, value.to_s, options[:comp_all_paths]) || value
      end  
    }

    formated_new_value = format_value_lambda.call(changed_value)

    (changed_value.blank? || formated_new_value.blank?) ? "" : "#{I18n.t(field.to_sym, scope: i18n_scope)} to <strong>#{formated_new_value}</strong>"
  end

  ##
  # In the Approval web page, add an "Approval Log" widget under the "Approve Document" widget.  
  # This will only show logs relating to when a document has been approved or not approved.  
  # It should show the user name who and what sections they approved or didn't approve to.  
  # For example:  Changed by Joel Keane....Add Approval to: and list sections it was approved to.  OR Changed by Joel Keane....Not accountable
  ##
  # approve_all: "Approve to all users in approver area"
  # approve_selected_areas: "approved to the specific areas"
  # not_approve: "Not accountable for approver section(s)."
  # field :approve_document_to, type: String

  # field :approved_paths, type: Array, default: []
  def self.document_approval_logs(user, company, document, page = 1, per_page = PER_PAGE)
    i18n_scope = [:logs, :approval_log]
    comp_all_paths = company.all_paths_hash

    approver_docs = document.approver_documents.includes(:user).order([:updated_at, :desc]).page(page).per(per_page)

    return_data = {
      "aaData" => [],
      "iTotalDisplayRecords" => approver_docs.length,
      "iTotalRecords" => approver_docs.total_count
    }

    approver_docs.each do |approver_doc|
      approver_name = approver_doc.user.try(:name)

      if approver_doc.approve_document_to == "not_approve"
        act_text = I18n.t(:not_approve, scope: i18n_scope, user_name: approver_name)
      else
        approved_areas = approver_doc.approved_paths.map { |e| area_name(company, e, comp_all_paths) }

        act_text = I18n.t(:approve, scope: i18n_scope, user_name: approver_name)
        
        act_text << "<ul>"
        approved_areas.each do |area|
          act_text << "<li>#{area}</li>"
        end
        act_text << "</ul>"
      end

      user_url = ActionController::Base.helpers.link_to(approver_name, (Rails.application.routes.url_helpers.users_path(search: approver_name) rescue ""), target: "_blank")

      return_data["aaData"] << {
        action_time: BaseService.time_formated(company, approver_doc.updated_at),
        log: act_text,
        user_url: user_url,
        user_name: approver_name
      }
    end

    return_data
  end

  def self.create_log(company_id, log_hash)
    ActivityLog.with(collection: "#{company_id}_activity_logs").create(log_hash)
  end
end