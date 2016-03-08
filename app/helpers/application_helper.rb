module ApplicationHelper
  include ActionView::Helpers::AssetTagHelper
  include ActionView::Helpers::NumberHelper

  COUNTRY_ARR = ["Afghanistan", "Albania", "Algeria", "American Samoa", "Angola", "Anguilla", "Antartica", "Antigua and Barbuda", "Argentina", "Armenia", "Aruba", "Ashmore and Cartier Island", "Australia", "Austria", "Azerbaijan", "Bahamas", "Bahrain", "Bangladesh", "Barbados", "Belarus", "Belgium", "Belize", "Benin", "Bermuda", "Bhutan", "Bolivia", "Bosnia and Herzegovina", "Botswana", "Brazil", "British Virgin Islands", "Brunei", "Bulgaria", "Burkina Faso", "Burma", "Burundi", "Cambodia", "Cameroon", "Canada", "Cape Verde", "Cayman Islands", "Central African Republic", "Chad", "Chile", "China", "Christmas Island", "Clipperton Island", "Cocos (Keeling) Islands", "Colombia", "Comoros", "Congo, Democratic Republic of the", "Congo, Republic of the", "Cook Islands", "Costa Rica", "Cote d'Ivoire", "Croatia", "Cuba", "Cyprus", "Czeck Republic", "Denmark", "Djibouti", "Dominica", "Dominican Republic", "Ecuador", "Egypt", "El Salvador", "Equatorial Guinea", "Eritrea", "Estonia", "Ethiopia", "Europa Island", "Falkland Islands (Islas Malvinas)", "Faroe Islands", "Fiji", "Finland", "France", "French Guiana", "French Polynesia", "French Southern and Antarctic Lands", "Gabon", "Gambia, The", "Gaza Strip", "Georgia", "Germany", "Ghana", "Gibraltar", "Glorioso Islands", "Greece", "Greenland", "Grenada", "Guadeloupe", "Guam", "Guatemala", "Guernsey", "Guinea", "Guinea-Bissau", "Guyana", "Haiti", "Heard Island and McDonald Islands", "Holy See (Vatican City)", "Honduras", "Hong Kong", "Howland Island", "Hungary", "Iceland", "India", "Indonesia", "Iran", "Iraq", "Ireland", "Ireland, Northern", "Israel", "Italy", "Jamaica", "Jan Mayen", "Japan", "Jarvis Island", "Jersey", "Johnston Atoll", "Jordan", "Juan de Nova Island", "Kazakhstan", "Kenya", "Kiribati", "Korea, North", "Korea, South", "Kuwait", "Kyrgyzstan", "Laos", "Latvia", "Lebanon", "Lesotho", "Liberia", "Libya", "Liechtenstein", "Lithuania", "Luxembourg", "Macau", "Macedonia, Former Yugoslav Republic of", "Madagascar", "Malawi", "Malaysia", "Maldives", "Mali", "Malta", "Man, Isle of", "Marshall Islands", "Martinique", "Mauritania", "Mauritius", "Mayotte", "Mexico", "Micronesia, Federated States of", "Midway Islands", "Moldova", "Monaco", "Mongolia", "Montserrat", "Morocco", "Mozambique", "Namibia", "Nauru", "Nepal", "Netherlands", "Netherlands Antilles", "New Caledonia", "New Zealand", "Nicaragua", "Niger", "Nigeria", "Niue", "Norfolk Island", "Northern Mariana Islands", "Norway", "Oman", "Pakistan", "Palau", "Panama", "Papua New Guinea", "Paraguay", "Peru", "Philippines", "Pitcaim Islands", "Poland", "Portugal", "Puerto Rico", "Qatar", "Reunion", "Romainia", "Russia", "Rwanda", "Saint Helena", "Saint Kitts and Nevis", "Saint Lucia", "Saint Pierre and Miquelon", "Saint Vincent and the Grenadines", "Samoa", "San Marino", "Sao Tome and Principe", "Saudi Arabia", "Scotland", "Senegal", "Seychelles", "Sierra Leone", "Singapore", "Slovakia", "Slovenia", "Solomon Islands", "Somalia", "South Africa", "South Georgia and South Sandwich Islands", "Spain", "Spratly Islands", "Sri Lanka", "Sudan", "Suriname", "Svalbard", "Swaziland", "Sweden", "Switzerland", "Syria", "Taiwan", "Tajikistan", "Tanzania", "Thailand", "Tobago", "Toga", "Tokelau", "Tonga", "Trinidad", "Tunisia", "Turkey", "Turkmenistan", "Tuvalu", "Uganda", "Ukraine", "United Arab Emirates", "United Kingdom", "Uruguay", "USA", "Uzbekistan", "Vanuatu", "Venezuela", "Vietnam", "Virgin Islands", "Wales", "Wallis and Futuna", "West Bank", "Western Sahara", "Yemen", "Yugoslavia", "Zambia", "Zimbabwe"]
  def current_company
    @current_company ||= Company.find(session[:company_id]) if session[:company_id]
  end

  def country_options(current_country = nil)
    html = ''
    COUNTRY_ARR.each do |country|
      if country == current_country
        html += '<option value="'+country+'"selected>'+country+'</option>'
      else
        html += '<option value="'+country+'">'+country+'</option>'
      end
    end
    html.html_safe
  end

  def right_nav_items(user, company)
    new_doc = company.documents.new
    new_user = company.users.new

    items = {
      new_document: {                 #Only users with Add / Edit Documents permission see this
        title: "New Document",
        path: new_document_path,
        action: :create,
        object: new_doc
      },
      new_user: {                 #Only users with Add / Edit Documents permission see this
        title: "New User",
        path: new_user_path,
        action: :create,
        object: nil,
        show: PermissionService.has_perm_add_edit_user(user, company, nil)
      },
      documents: {
        title: "Documents",
        path: documents_path,
        action: :index,
        object: nil,
        show: true
      },
      users: {
        title: "Users",               #If user has any add/edit user permission, show this
        path: users_path,
        action: :create,
        object: nil,
        show: PermissionService.has_perm_see_users(user, company)
      },
      logs: {
        title: "Logs",
        path: logs_company_path(company),
        action: :read,
        object: nil,
        show: true
      },
      reports: {
        title: "Reports",
        path: reports_path,
        action: :create,
        object: nil,
        show: true
      },
      compliance: {
        title: "Compliance",
        path: compliance_company_path(company),
        action: :compliance,
        object: company
      },
      organization_structure: {         #Need View / Edit Company Billing Info / Data Usage permission to see this
        title: "Organisation",
        path: structure_company_path(company),
        action: :add_org_node,
        object: company
      },
      permissions: {                    #Need View / Edit Company Billing Info / Data Usage permission to see this
        title: "Permissions",
        path: permissions_path,
        action: :create,
        object: company.permissions.new
      },
      document_setting: {               #Only users with Add / Edit Documents permission see this
        title: "Document Settings",
        path: settings_documents_path,
        action: :settings,
        object: new_doc
      },
      edit_company: {                   #Need View / Edit Company Billing Info / Data Usage permission to see this
        title: "Company Info",
        path: edit_company_path(company),
        action: :update,
        object: company
      }
    }

    items.keys.each do |key|
      item = items[key]
      if item[:show].nil? && item[:object]
        item[:show] = PermissionService.has_permission(item[:action], user, company, item[:object])
      end
    end

    items
  end

  def current_search
    result = {
      path: documents_path,
      placeholder: "Search Documents...",
      method: :get,
      fields: ["filter", "category_id"]
    }
    
    if params["controller"] == "users"
      result = {
        path: users_path,
        placeholder: "Search Users...",
        method: :get,
        fields: []
      }
    elsif params["action"] == "logs"
      result = {
        path: logs_company_path,
        placeholder: "Search Logs...",
        method: :get,
        fields: []
      }
    end

    result
  end

  ##
  # 
  # - Unread documents
  # - Documents to Approve:
  # - For the Administrator's' attention:
  # - Staff with outstanding Documents:
  # - Administrator Contact:
  # - Total of active users:
  # - Private Folder Usage
  # - Account Type
  #
  # Permissions:
  #  Any: Administrator contact, Private Folder Usage, User Type, Account type, Unread documents
  #  Administrator, Company Rep:  For the Administrator's attention
  #  Supervisor:  Staff with outstanding Documents
  #  Approver:  Documents to Approve
  ##
  def items_on_dashboard(user, company)
    items = {
      unread_documents: {
        show: true,
        length: 6
      },
      documents_to_approve: {
        show: false,
        perms: [:is_approval_user],
        length: 6
      },
      admin_attention: {
        show: false,
        user_types: [:admin_user, :company_representative_user],
        length: 6
      },
      staff_with_outstanding_documents: {
        show: false,
        perms: [:view_all_user_read_receipt_reports_under_assignment, :view_all_user_read_receipt_reports],
        length: 6
        #This only shows users in the same part of the company as them.
      },
      areas_without_accountable_documents: {
        show: false,
        perms: [:is_approval_user],
        length: 6
      },
      # admin_contact: {
      #   show: true,
      #   length: 6
      # },
      active_users: {
        show: false,
        perms: [:view_edit_company_billing_info_data_usage, :add_edit_company_representative_user, 
          :add_edit_admin_user],
        length: 6
      },
      private_folder_usage: {
        show: true,
        length: 6
      },
      # account_type: {
      #   show: true,
      #   length: 3
      # },
      user_type: {
        show: true,
        length: 6
      },
      unread_percentage: {
        show: true,
        length: 6
      },
      team_unread_percentage: {
        show: false,
        perms: [:is_supervisor_user],
        length: 6
      }
    }

    if company.is_standard?
      items.delete(:documents_to_approve)
    end

    if user.admin || user.super_help_desk_user
      items.keys.each do |i|
        items[i][:show] = true
      end

      items.delete(:unread_percentage) unless user.user_company(company)
      items.delete(:team_unread_percentage)

      return items
    end

    #Other users
    u_comp = user.user_company(company)
    return items unless user_comp_perm = u_comp.permission

    items[:documents_to_approve][:show] = u_comp.is_approver if !company.is_standard?
    #items[:admin_attention][:show] = u_comp[:show_admin_detail]
    items[:staff_with_outstanding_documents][:show] = u_comp.is_supervisor

    items.keys.each do |key|
      item = items[key]

      next if item[:show]

      item[:show] = false
      perms = item[:perms] || []

      perms.each do |e|
        if user_comp_perm[e]
          item[:show] = true
          break
        end
      end

      next if item[:show]

      user_types = item[:user_types] || []
      user_types.each do |e|
        if u_comp[:user_type] == e.to_s
          item[:show] = true
          break
        end
      end
    end

    items
  end

  ##
  #[:admin_contact, :active_users, :private_folder_usage, :account_type]
  # Check visibility 
  # & Calculate the number of row and panel metric items on each row
  ## 
  def visible_panel_metrics(dashboard_items)
    visible_items = []
    crr_length = 0
    crr_row = []
    max_length = 12

    if dashboard_items.has_key?(:admin_contact)
      admins = UserService.get_admins(current_user, current_company)

      admins.each do |admin|
        item = {partial: "home/admin_contact", locals: {admin: admin, div_length: dashboard_items[:admin_contact][:length]}}
        crr_length += dashboard_items[:admin_contact][:length]

        if crr_length > max_length
          crr_length = dashboard_items[:admin_contact][:length]
          visible_items << crr_row
          crr_row = [item]
        else
          crr_row << item
        end
      end
    end

    [:active_users, :private_folder_usage, :user_type, :unread_percentage, :team_unread_percentage].each do |key|
      next unless (dashboard_items[key][:show] rescue false)
      
      item = {partial: "home/#{key.to_s}", locals: {div_length: dashboard_items[key][:length]}}
      crr_length += dashboard_items[key][:length]
      if crr_length > max_length
        crr_length = dashboard_items[key][:length]
        visible_items << crr_row
        crr_row = [item]
      else
        crr_row << item
      end
    end

    visible_items << crr_row

    visible_items
  end

  # %li
  #   %a.notification{:href => "javascript:;"}
  #     .notification-thumb.pull-left
  #       = image_tag "demo/thumb1.png", class: "doc-icon-right pull-left"
  #     .notification-body
  #       %strong Unread: Document title
  #       %br
  #         %small.text-muted 8:58PM 5/12/14
  # %li
  #   %a.notification{:href => "javascript:;"}
  #     .notification-thumb.pull-left
  #       %i.fa.fa-warning.fa-2x
  #     .notification-body
  #       %strong Panel A needs Approver
  #       %br
  #         %small.text-muted 8:58PM 5/12/14
  def notifications_formated(company, notis, show_in_index = false)
    return [] if notis.length == 0

    noti_lis = []
    all_paths = company.all_paths_hash
    docs = {}

    notis.each do |e|
      icon = e.document_id ? image_tag( "demo/thumb1.png", class: "doc-icon-right pull-left") : "<i class='fa fa-warning fa-2x'></i>"
      
      if e.type == "credit_card_invalid"
        href = edit_company_path(company)
        text = e.send("#{e.type}_text".to_sym)
      elsif e.document_id
        unless doc = docs[e.document_id]
          doc = e.document
          docs[e.document_id] = e.document
        end
        href = Rails.application.routes.url_helpers.document_version_path(doc, doc.current_version) rescue "javascript:;"
        
        if e.type == Notification::TYPES[:document_to_approve][:code]
          href = Rails.application.routes.url_helpers.to_approve_document_path(doc)
        elsif e.type == Notification::TYPES[:document_upload_error][:code]
          href = Rails.application.routes.url_helpers.edit_document_path(doc)
        end

        text = e.send("#{e.type}_text".to_sym, docs)
      else
        href = "#"
        text = e.send("#{e.type}_text".to_sym, all_paths)
      end

      if show_in_index
        class_perm = (href == "#" ? "has-no-perm" : "has-perm")
        html = "<a class='list-group-item #{class_perm} notification noti-#{e.id}' href='#{href}'>" +
                  "<div class='notification-thumb pull-left'>" +
                    icon +
                  "</div>" +
                  "<div class='notification-body'>" +
                    "<strong>" + text + "</strong>" +
                    "<br>" + 
                    "<small class='text-muted'>" + BaseService.time_formated(company, e.created_at) + "</small>" +
                  "</div>" +
                "</a>"
      else
        html = "<li>" +
                "<a class='notification noti-#{e.id}' href='#{href}'>" +
                  "<div class='notification-thumb pull-left'>" +
                    icon +
                  "</div>" +
                  "<div class='notification-body'>" +
                    "<strong>" + text + "</strong>" +
                    "<br>" + 
                    "<small class='text-muted'>" + BaseService.time_formated(company, e.created_at) + "</small>" +
                  "</div>" +
                "</a>" +
                "</li>"
      end

      noti_lis << html
    end

    noti_lis
  end

  ##
  #
  ##
  def left_nav_items
    is_docs = (params[:controller] == "documents" && params[:action] == "index")

    items = [
      {
        title: t("navigations.dashboard.title"),
        path: dashboard_path,
        active: params[:action] == "dashboard",
        icon: "fa-home",
        code: "dashboard"
      },
      {
        title: t("navigations.favourite.title"),
        path: documents_path(filter: "favourite"),
        active: (is_docs && params[:filter] == "favourite"),
        icon: "fa-star",
        unread_number: 0,
        code: "favourite"
      },
      {
        title: t("navigations.unread.title"),
        path: documents_path(filter: "unread"),
        active: (is_docs && params[:filter] == "unread"),
        icon: "fa-file-text",
        unread_number: current_user.docs(current_company, "unread")[:unread_number],
        code: "unread"
      },
      {
        title: t("navigations.private.title"),
        path: documents_path(filter: "private"),
        active: (is_docs && params[:filter] == "private"),
        icon: "fa-lock",
        unread_number: 0,
        code: "private"
      },
      {
        title: t("navigations.all.title"),
        path: documents_path,
        active: (is_docs && !["favourite", "unread", "private", "inactive", "to_approve"].include?(params[:filter])),
        icon: "fa-copy",
        unread_number: 0,
        code: "all"
      }
    ]

    u_comp = current_user.user_company(current_company, true)
    can_add_edit_document = PermissionService.can_add_edit_document(current_user, current_company, u_comp)

    if !current_company.is_standard? && ((u_comp["is_approver"] rescue false) || 
      current_user.admin || current_user.super_help_desk_user)
      items << {
        title: t("navigations.to_approve.title"),
        path: documents_path(filter: "to_approve"),
        active: (is_docs && params[:filter] == "to_approve" ),
        icon: "fa-thumbs-up",
        unread_number: current_user.docs(current_company, "to_approve")[:docs].count,
        code: "to_approve"
      }
    end

    if can_add_edit_document
      items <<{
        title: t("navigations.inactive.title"),
        path: documents_path(filter: "inactive"),
        active: (is_docs && params[:filter] == "inactive" ),
        icon: "fa-trash-o",
        unread_number: 0,
        code: "inactive"
      }
    end

    items
  end

  ##
  # Get and render terms and conditions (asset url) from boxview
  ##
  def terms_and_conditions_assets_url
    assets_url = ""
    
    if (s_f = StaticFile.where(name: StaticFile::TERMS_AND_CONDITIONS).first)
      view_url, assets_url = s_f.get_box_url
    end
    
    assets_url
  end

  ##
  # Get and render terms and conditions (view_url) from boxview
  ##
  def terms_and_conditions_view_url
    view_url = ""
    
    if (s_f = StaticFile.where(name: StaticFile::TERMS_AND_CONDITIONS).first)
      view_url, assets_url = s_f.get_box_url
    end
    
    view_url
  end

  def render_number(number)
    number_with_delimiter(number)
  end

  ##
  # get the name of paths
  ##
  def name_of_paths(company, paths)
    all_paths = company.all_paths_hash

    paths.map { |e| all_paths[e] }
  end

  # This is colour coded. 0-5% Green, 6-10% Yellow, 11-15% Orange and >15% red. 
  def unread_percentage_color(num)
    num = num.to_f if num.is_a?(Fixnum)
    if (num.nan? rescue nil)
      ''
    elsif num >= 0 && num <= 5
      'green'
    elsif num >= 6 && num <= 10
      'yellow'
    elsif num >= 11 && num <= 15
      'orange'
    else
      'red'
    end
  end

  def show_percentage(num)
    num = num.to_f if num.is_a?(Fixnum)
    num.nan? ? "" : "#{num}%"
  end
end
