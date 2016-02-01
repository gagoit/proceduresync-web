class ReportService < BaseService
  
  #  report_setting: { 
  #    areas: path id (just Add/edit document permission will have it)
  #    users: all/user's id 
  #    doc_status: all/read/unread
  #    categories: all/category's id
  #  }  
  def self.get_report(user, company, report_setting)
    u_comp = user.user_company(company, true)
    comp_all_paths_hash = company.all_paths_hash
    user_ids = []
    can_see_user_ids = report_user_ids(user, company).map { |e| e.to_s }
    report_by_areas = false

    #For areas field
    can_add_edit_doc = PermissionService.can_add_edit_document(user, company, u_comp)
    report_setting[:areas] = ReportSetting::SELECT_USERS_TEXT unless can_add_edit_doc

    user_ids = report_setting[:users] || []

    if report_setting[:areas] && report_setting[:areas] != ReportSetting::SELECT_USERS_TEXT
      user_ids = report_user_ids_in_part_of_org(user, company, report_setting[:areas])
      report_setting[:areas_name] = comp_all_paths_hash[report_setting[:areas]]
      report_by_areas = true
    end

    if user_ids.include?("all")
      user_ids = report_user_ids(user, company)
    elsif user_ids.include?("my_team")
      user_ids.concat(report_user_ids_in_part_of_org(user, company, u_comp["supervisor_path_ids"])) if u_comp
    end

    user_ids.delete("all")
    user_ids.delete("my_team")

    user_ids = user_ids.map { |e| e.to_s }

    user_ids = (user_ids & can_see_user_ids) unless (report_by_areas && can_add_edit_doc)
    
    query = {}
    query_users = {:user_id.in => user_ids}

    return blank_report(company, report_setting) if user_ids.blank?

    report_setting[:categories] ||= []
    docs_hash = {}
    doc_ids_in_cates = company.documents.active.public_all
    doc_ids_in_cates = doc_ids_in_cates.where(:category_id.in => report_setting[:categories]) unless report_setting[:categories].include?("all")

    doc_ids_in_cates.pluck(:id, :title, :created_time, :category_name).each do |e|
      docs_hash[e[0]] = [e[1], e[2], (e[3] || "Private")] #:title, :created_time, :category_name
    end

    doc_ids = docs_hash.keys

    return blank_report(company, report_setting) if doc_ids.blank?

    query_docs = {:target_document_id.in => doc_ids}

    users = company.users.where(:id.in => user_ids)
    users_hash = {}

    doc_status = (report_setting[:doc_status] == "all") ?  ["read", "unread"] : [report_setting[:doc_status]]

    csv_data = [] #["User", "Email", "Area", "Action", "Document", "Category", "Action Time"]
    if doc_status.include?("unread")
      users.each do |u|
        users_hash[u.id] = [u.name, u.email, u.read_document_ids, u.user_companies_info]
        u_unread_doc_ids = u.docs(company, "unread")[:docs].active.pluck(:id)

        u_unread_doc_ids.each do |doc_id|
          doc = docs_hash[doc_id]
          next unless doc
          csv_data << [u.name, u.email, (comp_all_paths_hash[u.user_companies_info[company.id.to_s]["company_path_ids"]] rescue ""), "Unread", doc[0], doc[2], doc[1]]
        end
      end
    end

    logs = []
    if doc_status.include?("read")
      query.merge!(query_users)
      query.merge!(query_docs)

      query[:action] = ActivityLog::ACTIONS[:read_document]

      logs = company.logs.where(query).order([:action_time, :desc]).pluck(:user_id, :target_document_id, :action, :action_time, :created_at)

      if logs.length > 0
        if users_hash.blank?
          users = users.pluck(:id, :name, :email, :read_document_ids, :user_companies_info)
          users.each{|e| users_hash[e[0]] = [e[1], e[2], e[3], e[4]]} #:name, :read_document_ids, :user_companies_info
        end

        logs.each do |log|
          next unless doc = docs_hash[log[1]]
          u = users_hash[log[0]]

          csv_data << [ u[0], u[1], (comp_all_paths_hash[u[3][company.id.to_s]["company_path_ids"]] rescue ""), "Read", doc[0], doc[2], log[3]]
        end
      end
    end

    #Have user reports sorted by A-Z user name
    csv_data.sort! { |a, b| a[0].to_s.downcase <=> b[0].to_s.downcase }

    file = CSV.generate({:write_headers => true}) do |csv|
      csv << ["User", "Email", "Area", "Action", "Document", "Category", "Action Time"]
      
      csv_data.each do |e|
        e[6] = time_formated(company, e[6])
        csv << e
      end
    end

    {
      file: file,
      name: name_of_report(company, report_setting)
    }
  end

  def self.blank_report(company, report_setting)
    file = CSV.generate({:write_headers => true}) do |csv|
      csv << ["User", "Email", "Area", "Action", "Document", "Category", "Action Time"]
    end

    {
      file: file,
      name: name_of_report(company, report_setting)
    }
  end

  def self.name_of_report(company, report_setting, report_type = nil)
    if report_setting[:areas_name].blank?
      report_name = "reports.csv"
    else
      report_name = "#{report_type ? report_type.to_s + '-in-' : ''}#{report_setting[:areas_name].gsub(Company::NODE_SEPARATOR, '_').gsub(' ', '-')}_#{time_formated(company, Time.now.utc, '%l:%M%p-%d/%m/%y').strip}.csv"
    end
  end

  ##
  # Get users who are available in report for current user
  #If you have View All User Read Receipt Reports permission, you will be able to select any Users. 
  #If you don't you are only able to select the parts of the organisation that you are assigned to, and yourself.
  # - Standard User's and Document Control Standard Users should only be able to select themselves to be included in the report.  
  #   They should not have an "All" option.
  # - Supervisor and above can select "All" and get everyone in their division.
  ##
  def self.report_user_ids(user, comp)
    return comp.users.active.pluck(:id) if user.admin || user.super_help_desk_user

    u_comp ||= user.user_company(comp, true)

    return [] unless (u_comp_perm = user.comp_permission(comp, u_comp, true))

    viewable_paths = []
    user_ids =  if u_comp_perm[:view_all_user_read_receipt_reports]
                    comp.users.active.pluck(:id)
                  elsif u_comp_perm[:view_all_user_read_receipt_reports_under_assignment]
                    viewable_paths = [u_comp['company_path_ids']]
                    []
                  else
                    [user.id]
                  end

    if u_comp["is_supervisor"] && !u_comp_perm[:view_all_user_read_receipt_reports]
      viewable_paths.concat(u_comp['supervisor_path_ids'])
    end

    if u_comp["is_approver"] && !u_comp_perm[:view_all_user_read_receipt_reports]
      viewable_paths.concat(u_comp['approver_path_ids'])
    end

    unless viewable_paths.blank?
      member_ids = comp.user_companies.active.where(:company_path_ids.in => viewable_paths).pluck(:user_id)

      user_ids.concat(member_ids)
      user_ids.uniq!
    end

    user_ids
  end

  ##
  # Get users who are available in report WS for current user
  # only return users that belong to areas that current user is supervising
  ##
  def self.report_ws_user_ids(user, comp)
    return comp.users.active.pluck(:id) if user.admin || user.super_help_desk_user

    u_comp ||= user.user_company(comp, true)

    return [] unless (u_comp_perm = user.comp_permission(comp, u_comp, true))

    if u_comp["is_supervisor"] && !u_comp['supervisor_path_ids'].blank?
      comp.user_companies.active.where(:company_path_ids.in => u_comp['supervisor_path_ids']).pluck(:user_id) - [user.id]
    else
      []
    end
  end

  ##
  # Get users who are available in part of organisation
  ##
  def self.report_user_ids_in_part_of_org(user, comp, belongs_to_paths)
    if user.admin || user.super_help_desk_user
    else
      u_comp ||= user.user_company(comp, true)

      u_comp_perm = user.comp_permission(comp, u_comp, true)
      return [] if u_comp_perm.nil?
    end

    areas = belongs_to_paths.is_a?(Array) ? belongs_to_paths : [belongs_to_paths]

    all_report_user_ids = report_user_ids(user, comp)
    filter_report_user_ids = comp.user_companies.active.where(:company_path_ids.in => areas).pluck(:user_id)

    all_report_user_ids & filter_report_user_ids
  end

  ##
  # Filter part of organisation in Accoutability Rerport:
  # "View All Accountability Reports" allows user to see all areas
  # "View Accountability  Reports under Assignment" allows user to see areas that they supervise/approve 
  #      and belong to
  # With no permission of "View All Accountability Reports" & "View Accountability Reports under Assignment" -
  #       users only see their area
  ##
  def self.company_paths_for_accountability_report(user, comp)
    return comp.company_paths if user.admin || user.super_help_desk_user

    u_comp ||= user.user_company(comp, true)
    user_comp_perm = user.comp_permission(comp, u_comp, true)

    return [] if u_comp.blank? || user_comp_perm.blank?

    if user_comp_perm[:view_all_accountability_reports]
      comp.company_paths
    elsif user_comp_perm[:view_accountability_reports_under_assignment]
      areas = []
      area_ids = [u_comp["company_path_ids"]]
      all_paths_hash = comp.all_paths_hash
      
      area_ids.concat(u_comp["supervisor_path_ids"]) if u_comp["is_supervisor"]
      area_ids.concat(u_comp["approver_path_ids"]) if u_comp["is_approver"]
      area_ids.uniq!

      area_ids.each do |path_id|
        areas << [ all_paths_hash[path_id], path_id ]
      end

      areas
    else
      [[ comp.all_paths_hash[u_comp["company_path_ids"]], u_comp["company_path_ids"] ]]
    end
  end

  ##
  # Daily/Monthly/Weekly/Fortnightly Emailed reports
  ##
  def self.auto_emailed_reports(frequency = "daily")
    daily_reports = ReportSetting.send(frequency).auto_email.order([[:user_id, :desc]])

    generate_reports(daily_reports)
  end

  ##
  # Generate Reports and send email
  ##
  def self.generate_reports(report_settings)
    users_hash = {}
    companies_hash = {}
    user_reports = []
    prev_u_id = ""
    prev_user = nil

    report_settings.each_with_index do |report_setting, index|
      user = (users_hash[report_setting.user_id] || report_setting.user)
      company = (companies_hash[report_setting.company_id] || report_setting.company)

      next if user.blank? || company.blank?

      if prev_u_id != user.id.to_s
        #Email for previous user
        UserMailer.report(prev_user, user_reports).deliver unless (user_reports.blank? || prev_user.blank?)
        user_reports = []
      else

      end

      report_hash = {users: report_setting.users, doc_status: report_setting.doc_status.downcase, 
        categories: report_setting.categories, areas: report_setting.areas.downcase}

      if comp_user_reports = get_report(user, company, report_hash)
        comp_user_reports[:name] = "#{report_setting.frequency} #{company.name}'s #{comp_user_reports[:name]}"
        comp_user_reports[:company_id] = company.id
        comp_user_reports[:company_name] = company.name
        user_reports << comp_user_reports
      end

      users_hash[report_setting.user_id] = user
      companies_hash[report_setting.company_id] = company
      prev_user = user
    end

    #Email for last user
    UserMailer.report(prev_user, user_reports).deliver unless (user_reports.blank? || prev_user.blank?)
  end

  ##
  # Accoutable Report for a part of organisation
  # it's about accountable document in each company's area
  # It should show in the CSV the company section, category and document name
  # Accountability report CSV: order it by company, category and document.
  ##
  def self.get_accountable_report(user, company, report_setting)
    docs = company.documents.active.effective.where(:approved_paths.in => [report_setting[:areas]]).pluck(:title, :category_name)

    file = CSV.generate({:write_headers => true}) do |csv|
      csv << ["Area", "Category", "Document"]
      
      docs.each do |doc|
        csv << [report_setting[:areas_name], doc[1].to_s, doc[0]]
      end
    end

    {
      file: file,
      name: name_of_report(company, report_setting, "accountability_report")
    }
  end

  ##
  # For Admin and Super Admin users, the ability to select a section within the organisation 
  # and download a report that shows “active” users who supervisor for or approve for that section.  
  # The CSV  would have “Name”, “Email”, “Supervise For” & “Approve For”.
  ##
  def self.get_supervisors_approvers_report(user, company, report_setting)
    user_comps = company.user_companies.includes([:user]).any_of({is_approver: true, :approver_path_ids.in => [report_setting[:areas]]}, 
                                    {is_supervisor: true, :supervisor_path_ids.in => [report_setting[:areas]]})

    all_paths_hash = company.all_paths_hash

    file = CSV.generate({:write_headers => true}) do |csv|
      csv << ["Division:", all_paths_hash[report_setting[:areas]].to_s, "", ""]
      csv << ["", "", "", ""]
      csv << ["Name", "Email", "Supervise For", "Approve For"]
      
      user_comps.each do |user_comp|
        next unless (user = user_comp.user)
        s_areas = (user_comp.supervisor_path_ids || []) #.map { |e| all_paths_hash[e] }.join(", ")
        a_areas = (user_comp.approver_path_ids || [])   #.map { |e| all_paths_hash[e] }.join(", ")

        csv << [user.name, user.email, yes_no_text(s_areas.include?(report_setting[:areas])), yes_no_text(a_areas.include?(report_setting[:areas])) ]
      end
    end

    {
      file: file,
      name: name_of_report(company, report_setting, "supervisors_approvers_report")
    }
  end

  ##
  # Reports WS
  # @response:
  #  [ 
  #        {
  #             name: ,
  #             users: [
  #                 { name, unread_number, docs: {uid, id, title} },  
  #                 { name, unread_number, docs: {uid, id, title} }
  #             ]
  #        }, 
  #        {
  #              name: ,
  #              users: []
  #         } 
  #  ] 
  ##  
  def self.get_report_ws(user)
    result = []
    user.companies.active.order([[:name, :asc]]).each do |company|
      u_comp = user.user_company(company, true)

      next unless u_comp["is_supervisor"]

      company_hash = {
        uid: company.id.to_s,
        name: company.name,
        logo_url: company.logo_iphone4_url,
        users: []
      }

      all_user_ids = report_ws_user_ids(user, company)
      user_ids = all_user_ids.map { |e| e.to_s }
      
      users = company.users.active.where(:id.in => user_ids)

      users.each do |u|
        u_hash = {
          name: u.name,
          unread_number: 0,
          docs: []
        }

        u_unread_docs = u.docs(company, "unread")[:docs].active.pluck(:id, :title, :doc_id)

        u_unread_docs.each do |doc|
          u_hash[:docs] << {
            uid: doc[0].to_s,
            id: doc[2].to_s,
            title: doc[1]
          }

          u_hash[:unread_number] += 1
        end

        company_hash[:users] << u_hash
      end

      result << company_hash
    end

    result
  end
end