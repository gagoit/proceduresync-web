module PermissionHelper
  def standard_permissions_for_select(current_user, company)
    can_edit_user_types = PermissionService.can_edit_user_types(current_user, company)

    arr = []
    company.standard_permissions.where(:code.in => can_edit_user_types).pluck(:name, :id, :code).each do |e| 
      arr << [e[0], e[1], {:'data-code' => e[2]}] 
    end

    arr.insert(0, [t("permission.#{Permission::CUSTOM_PERMISSION_CODE}"), Permission::CUSTOM_PERMISSION_CODE])

    arr
  end

  def standard_user_types_for_select(company)
    can_edit_user_types = PermissionService.can_edit_user_types(current_user, company)

    arr = []
    Permission::STANDARD_PERMISSIONS.each do |key, value|
      next unless can_edit_user_types.include?(value[:code])

      arr << [value[:name], value[:code], {id: "perm_#{value[:code]}"}]
    end

    arr
  end

  def current_perm_comp_id(user, company)
    user.comp_permission(company).try(:id) || Permission::CUSTOM_PERMISSION_CODE
  end

  def permission_name(permission)
    if permission.is_custom
      name = permission.name
      
      name = permission.name.gsub("##{permission.for_user_id}", "for #{permission.for_user_name}")
    else
      permission.name
    end
  end

  def permissions_list(company)
    perms = Permission::RULES.keys
    if company.is_standard?
      perms.delete(:is_approval_user)
      perms.delete(:add_edit_approver_user)
    end

    perms
  end

  def has_perm_show_admin_detail(user, company)
    return true if user.admin? || user.super_help_desk_user?
    
    current_user_comp_perm = user.comp_permission(company)
    current_user_comp_perm.try(:add_edit_company_representative_user) || current_user_comp_perm.try(:add_edit_admin_user)
  end
end
