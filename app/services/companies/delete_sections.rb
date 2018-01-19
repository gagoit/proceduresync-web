class Companies::DeleteSections

  def self.call current_user, company, node_id, node_type
    return { success: false, reload: true } unless PermissionService.can_delete_section(company, current_user)

    node = company.company_structures.where(type: node_type).find(node_id)
    node_reference = Companies::GetReferenceInfoOfSection.call(company, node.path)
    can_delete = (node_reference[:active_users_count] == 0)

    unless can_delete
      return {
        success: false,
        reload: true
      }
    end

    paths = []
    paths_name = []
    company.company_structures.where(path: /#{node.path}/).order([:path, :asc]).each do |n|
      if n.child_ids.length == 0
        paths << n.path
        paths_name << company.all_paths_hash[n.path]
      end
    end

    # - Delete paths
    company.company_structures.where(path: /#{node.path}/).update_all({deleted: true, deleted_at: Time.now.utc})
    Rails.cache.delete("/company/#{company.id}-#{company.path_updated_at}/company_paths")
    Rails.cache.delete("/company/#{company.id}-#{company.path_updated_at}/all_paths")
    Rails.cache.delete("/company/#{company.id}-#{company.path_updated_at}/all_paths_hash")
    Rails.cache.delete("/company/#{company.id}-#{company.path_updated_at}/all_paths_include_deleted")
    Rails.cache.delete("/company/#{company.id}-#{company.path_updated_at}/all_paths_hash_include_deleted")

    company.path_updated_at = Time.now.utc
    if company.lowest_level != node_type
      all_types = Company::STRUCTURES.keys.map { |e| e.to_s }
      company.lowest_level = node_type if (all_types.index(company.lowest_level) < all_types.index(node_type) rescue true)
    end
    company.save(validate: false)

    company.create_logs({user_id: current_user.id, action: ActivityLog::ACTIONS[:deleted_organisation_structure], attrs_changes: {paths: paths, paths_name: paths_name}})

    # - Documents
    company.documents.where(:belongs_to_paths.in => paths).each do |doc|
      doc.belongs_to_paths -= paths
      doc.approved_paths -= paths
      doc.correct_paths

      # Don't use Actice Record Save operation to Reduce update_user_documents query
      doc.correct_paths
      Document.where(:id => doc.id).update_all(belongs_to_paths: doc.belongs_to_paths, approved_paths: doc.approved_paths, 
            not_approved_paths: doc.not_approved_paths, not_accountable_for: doc.not_accountable_for)
      doc.create_logs({ user_id: current_user.id, action: ActivityLog::ACTIONS[:updated_document], 
            attrs_changes: doc.changes })
    end

    # - Anyone that “Supervises” or “Approves” for these sections has them removed from their applicable sections.
    company.user_companies.includes(:user).any_of({:approver_path_ids.in => paths}, {:supervisor_path_ids.in => paths}).each do |u_comp|
      u_comp.approver_path_ids ||= []
      u_comp.supervisor_path_ids ||= []
      u_comp.approver_path_ids -= paths
      u_comp.supervisor_path_ids -= paths
      UserCompany.where(id: u_comp.id).update_all({approver_path_ids: u_comp.approver_path_ids, supervisor_path_ids: u_comp.supervisor_path_ids})

      user = u_comp.user
      user.user_companies_info[company.id.to_s]["approver_path_ids"] = u_comp.approver_path_ids
      user.user_companies_info[company.id.to_s]["supervisor_path_ids"] = u_comp.supervisor_path_ids
      User.where(id: user.id).update_all({user_companies_info: user.user_companies_info})
    end

    { 
      success: true, 
      message: I18n.t("company.delete_sections.success")
    }
  end
end