module UserHelper
  def comp_path_ids(user, comp)
    u_comp = user.user_company(comp)

    u_comp.try(:company_path_ids)
  end

  def account_type(user, comp)
    if user.admin 
      t("user.types.admin")
    elsif user.super_help_desk_user
      t("user.types.super_help_desk")
    else
      user.user_company(comp).user_type.titleize rescue ""
    end
  end

  def private_folder_size(user, comp)
    current_size = user.docs_size(comp, "private")
    current_size_in_mb = current_size / 1000000
    
    if comp.private_folder_size > 0
      { 
        percent: ((current_size_in_mb / comp.private_folder_size) * 100).round(2),
        current_size_in_mb: current_size_in_mb,
        remain_mb: (comp.private_folder_size - current_size_in_mb).round(2)
      }
    else
      { 
        percent: 100,
        current_size_in_mb: current_size_in_mb,
        remain_mb: 0
      }
    end
  end
end
