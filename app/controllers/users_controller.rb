class UsersController < ApplicationController
  before_filter :authenticate_user!, except: [:check_login_before]

  before_filter :check_company, except: [:check_login_before]

  SORT_MAP = {
    1 => "name",
    2 => "email",
    # 3 => "",
    # 4 => "",
    5 => "active"
  }

  # GET /users
  # GET /users.json
  def index
    if PermissionService.has_perm_see_users(current_user, current_company)
    else
      raise CanCan::AccessDenied
    end

    if request.xhr?
      per_page = params[:iDisplayLength] || OBJECT_PER_PAGE[:user]
      page = params[:iDisplayStart] ? ((params[:iDisplayStart].to_i/per_page.to_i) + 1) : 1
      params[:iSortCol_0] = 1 if params[:iSortCol_0].blank?

      sort_field = SORT_MAP[params[:iSortCol_0].to_i] || "name"
      
      @users = User.get_available_users(current_user, current_company, page, per_page, params[:search], [[sort_field, params[:sSortDir_0]]])

      render :json =>  @users

      return
    end

    @users = current_company.users
    @can_add_edit_user = PermissionService.has_perm_add_edit_user(current_user, current_company)

    respond_to do |format|
      format.html
      format.json { render json: @users }
    end
  end

  def edit
    if @user = current_company.users.where(id: params[:id]).first

      if PermissionService.has_permission(:edit, current_user, current_company, @user)
      elsif current_user.id == @user.id
        redirect_to profile_user_path(@user)
      else
        raise CanCan::AccessDenied
      end

    elsif (current_user.admin? || current_user.super_help_desk_user?) && current_user.id.to_s == params[:id]
      redirect_to profile_user_path(current_user)
    else
      raise CanCan::AccessDenied
    end
  end

  def new
    @user = current_company.users.new

    if PermissionService.has_permission(:new, current_user, current_company, @user)
    elsif current_user.id == @user.id
      redirect_to profile_user_path(@user)
    else
      raise CanCan::AccessDenied
    end
  end

  def profile
    if @user = current_company.users.where(id: params[:id]).first
      if PermissionService.has_permission(:profile, current_user, current_company, @user)
      else
        raise CanCan::AccessDenied
      end

    elsif (current_user.admin? || current_user.super_help_desk_user?) && current_user.id.to_s == params[:id]
      @user = current_user
    else
      raise CanCan::AccessDenied
    end
  end

  # GET /users/1
  # GET /users/1.json
  def show
    @user = User.find(params[:id])

    # render json: @user
    redirect_to edit_user_path(@user)
  end

  def create
    @user = current_company.users.new

    if PermissionService.has_perm_add_edit_user(current_user, current_company)
    else
      raise CanCan::AccessDenied
    end

    if existed_user = User.where(email_downcase: params[:user][:email].to_s.downcase).first
      if params[:user][:confirm_overwrite] == "true"
        #overwrite user, add new company to user
        @user = existed_user
        @user.updated_by_id = current_user.id

        result = @user.update_info(current_user, current_company, params)
      else
        result = {
          success: false, message: "", error_code: "user_existed", 
          message: t("user.edit.confirm_existed_user", {name: existed_user.name}),
          existed_user_url: edit_user_path(existed_user),
          existed_user_name: existed_user.name
        }

      end
    else
      @user.updated_by_id = current_user.id

      result = @user.update_info(current_user, current_company, params)
    end

    if result[:success]
      result[:return_url] = users_path
      result[:message] = "User has been created successfully"

      render json: result
    else
      render json: result
    end
  end

  # PATCH/PUT /users/1
  # PATCH/PUT /users/1.json
  def update
    admin_update_their_profile = has_perm_add_edit_user = false

    if @user = current_company.users.where(id: params[:id]).first

      if has_perm_add_edit_user = PermissionService.has_permission(:update, current_user, current_company, @user)
      elsif current_user.id == @user.id
      else
        raise CanCan::AccessDenied
      end

    elsif (current_user.admin? || current_user.super_help_desk_user?) && current_user.id.to_s == params[:id]
      @user = current_user
      admin_update_their_profile = has_perm_add_edit_user = true
    else
      raise CanCan::AccessDenied
    end

    @user.updated_by_id = current_user.id

    if params[:user][:prev_action] == "setup"

      if @user.update(user_params)
        sign_in @user, :bypass => true
        redirect_to dashboard_path
      else
        flash[:alert] = @user.errors.full_messages.first
        redirect_to setup_user_path(@user)
      end

    else #update user info
      update_profile = lambda { 
        changes = {}
        new_info = user_params(has_perm_add_edit_user)

        [:name, :email, :phone, :home_email, :encrypted_password].each do |f|
          if new_info.has_key?(f) && new_info[f] != @user[f]
            changes[f.to_s] = [@user[f], new_info[f]]
          end
        end

        if @user.update(new_info)
          @user.create_logs(current_company, {user_id: current_user.id, target_user_id: @user.id, action: ActivityLog::ACTIONS[:updated_user], attrs_changes: changes}) unless changes.blank?
          
          {success: true, message: "User has been updated successfully"}
        else
          {success: false, message: @user.errors.full_messages.first, error_code: @user.errors}
        end
      }

      if admin_update_their_profile
        result = update_profile.call
      else

        if has_perm_add_edit_user
          result = @user.update_info(current_user, current_company, params)
        else
          result = update_profile.call
        end

        if result[:success]
          if @user.id == current_user.id && params[:user].has_key?(:password)
            sign_in @user, :bypass => true
          end

          if result[:load_approver_supervisor]
            result[:approver_supervisor_html] = (render_to_string :partial => "users/approver_supervisor", locals: {u_comp: @user.user_company(current_company), is_showed: true}, formats: [:html])
          end

          result[:custom_permissions_html] = (render_to_string :partial => "users/custom_permissions", locals: { is_custom_perm: result[:is_custom_perm], 
              current_perm: (result[:is_custom_perm] ? result[:u_comp_perm] : {}), 
              u_comp: @user.user_company(current_company)}, formats: [:html])
        end
      end

      render json: result
    end
  end

  def setup
    render layout: "not_signed_in"
  end

  # PATCH/GET /users/change_company_view
  # PATCH/GET /users/change_company_view.json
  # params: {company_id}
  def change_company_view
    comps = (current_user.admin? || current_user.super_help_desk_user?) ? Company.all : current_user.companies
    if comp = comps.where(id: params[:company_id]).first
      session[:company_id] = comp.id

      render json: {success: true, success_url: dashboard_path}, status: :ok
    else
      render json: {success: false, message: "Company could not be found"}
    end
  end

  # PATCH/GET /users/check_login_before
  # PATCH/GET /users/check_login_before.json
  # params: {email}
  def check_login_before
    if user = User.where(email_downcase: params[:email].to_s.downcase).first
      result = {has_logged_in: false, success: true}

      result[:has_logged_in] = true if user.sign_in_count > 0

      render json: result, status: :ok
    else
      render json: {
        success: false,
        has_logged_in: false, 
        error_code: "email_not_found", 
        message: "Email is not found."
      }
    end
  end

  def load_more_unread_docs
    if @user = current_company.users.find(params[:id])

      viewable_user_ids = PermissionService.viewable_user_ids(current_user, current_company)

      if viewable_user_ids.include?(@user.id)
      else
        raise CanCan::AccessDenied
      end
    end

    unread_docs, total_count = Document.get_all(@user, current_company, {page: nil, per_page: nil, search: "", sort_by: [:title, :asc], filter: "unread"})

    render json: {success: true, unread_docs: unread_docs.pluck(:title).join(", ")}, status: :ok
  end

  ##
  # bulk assign many users to a different part of the organisation
  ##
  def update_path
    paths = params[:paths] || ""
    user_ids = params[:user_ids] || []
    search = params[:search]

    result = User.update_path(current_user, current_company, user_ids, paths)

    render json: result
  end

  def export_csv
    if PermissionService.has_permission(:read, current_user, current_company, current_company.users.new)
    else
      raise CanCan::AccessDenied
    end

    search = params[:search] || ''
    sort_field = SORT_MAP[params[:sort_column].to_i]
    ids = params[:ids] || "all"
    data = User.export_csv(current_user, current_company, search, [[sort_field, params[:sort_dir]]], ids)

    respond_to do |format|
      format.html
      format.csv {
        response.headers.delete("Pragma")
        response.headers.delete('Cache-Control')
        send_data data[:file], :filename => data[:name], type: 'text/csv', disposition: 'attachment'
      }
    end
  end

  ##
  # Show notification of a user in a company
  # also mark as read all notifications
  ##
  def notifications
    @notifications = current_user.get_notifications(current_company).limit(10)

    unread_noti_num = current_user.unread_notifications(current_company).count

    current_user.unread_notifications(current_company).update_all(status: Notification::READ_STATUS)

    render json: {
      success: true, 
      notis_html: (render_to_string :partial => "notifications/notifications", locals: {notifications: @notifications, show_see_more: true, unread_noti_num: unread_noti_num}, formats: [:html])
    }
  end

  def logs
    @user = User.find(params[:id])
    if current_user.id.to_s == params[:id] || PermissionService.has_permission(:edit, current_user, current_company, @user)
    else
      raise CanCan::AccessDenied
    end
    

    if request.xhr?
      per_page = params[:iDisplayLength] || PER_PAGE
      page = params[:iDisplayStart] ? ((params[:iDisplayStart].to_i/per_page.to_i) + 1) : 1
      params[:iSortCol_0] = 1 if params[:iSortCol_0].blank?
      
      @logs = LogService.user_logs(@user, current_user, current_company, page, per_page)

      render :json =>  @logs

      return
    end

    @logs = @user.logs(current_company).includes(:target_document, :target_user).order([:action_time, :desc])

    respond_to do |format|
      format.html
      format.json { render json: @logs }
    end
  end

  def devices
    @user = User.find(params[:id])

    if current_user.id.to_s == params[:id] || PermissionService.has_permission(:edit, current_user, current_company, @user)
    else
      raise CanCan::AccessDenied
    end

    if request.xhr?
      params[:iSortCol_0] = 1 if params[:iSortCol_0].blank?
      sort_fields = {
        1 => "device_name",
        2 => "token",
        3 => "os_version"
      }
      sort_field = sort_fields[params[:iSortCol_0]] || "device_name"
      
      devices = @user.devices.available.order([[sort_field, params[:sSortDir_0]]])

      return_data = {
        "aaData" => [],
        "iTotalDisplayRecords" => devices.length,
        "iTotalRecords" => devices.length
      }

      devices.each do |e|
        return_data["aaData"] << {
          id: e.id.to_s,
          token: e.token,
          platform: e.platform,
          name: e.device_name,
          os_version: e.os_version,
          remote_wipe_device_url: remote_wipe_device_user_path(@user, user_device_id: e.id.to_s),
          sent_test_notification_url: sent_test_notification_user_path(@user, user_device_id: e.id.to_s),
        }
      end

      render :json =>  return_data

      return
    end

    @devices = current_user.devices.available

    respond_to do |format|
      format.html
      format.json { render json: @devices }
    end
  end


  def remote_wipe_device
    @user = User.find(params[:id])

    if current_user.id == @user.id #|| PermissionService.has_permission(:edit, current_user, current_company, @user)
    else
      raise CanCan::AccessDenied
    end

    u_d = @user.devices.find(params[:user_device_id])
    
    NotificationService.delay.remote_wipe_device(@user, u_d.token, u_d.app_access_token)
    @user.devices.where(id: u_d.id).update_all(deleted: true)

    render json: {success: true, message: t("user.devices.remote_wipe.success")}
  end

  ##
  # Sent a test notification to a user's device
  ##
  def sent_test_notification
    @user = User.find(params[:id])

    if current_user.id == @user.id #|| PermissionService.has_permission(:edit, current_user, current_company, @user)
    else
      raise CanCan::AccessDenied
    end

    u_d = @user.devices.find(params[:user_device_id])
    
    NotificationService.delay.sent_test_notification(@user, u_d.token, u_d.app_access_token)

    render json: {success: true, message: t("user.devices.sent_notification.success")}
  end

  ##
  # Load permission for user type in Custom Permission in Add/Edit User page
  # @params: 
  # => code: code of user type
  # => permission_id: custom_permisison || perm's id
  ##
  def load_permsions_for_user_type
    if PermissionService.has_perm_add_edit_user(current_user, current_company)
    else
      raise CanCan::AccessDenied
    end

    if perm = current_company.permissions.where(code: params[:code]).first

    else
      raise CanCan::AccessDenied
    end

    render json: {
      success: true, 
      html: render_to_string(:partial => "users/available_permissions", 
              locals: {
                  current_perm: perm, 
                  is_custom_perm: (params[:permission_id] == Permission::CUSTOM_PERMISSION_CODE)
              }, 
              formats: [:html]) 
      }, status: :ok
  end

  #Have an action in the Admin for the super user: 
  #  "Mark All Read" for a specific user. This will mark that users accountable documents as read.
  def mark_all_as_read
    if current_user.admin || current_user.super_help_desk_user
    else
      raise CanCan::AccessDenied
    end

    @user = User.find(params[:id])

    @user.read_all_documents!

    render json: {success: true, message: t("user.mark_all_as_read.success")}
  end

  ##
  # Approver settings approval email:
  #  "No Approval Notification emails"
  #  "Send Approval Notification email instantly": default
  #  "Send Approval Notification email daily"
  #
  #  If it is set to daily, only send the email at the start of the next day (7am in there timezone)
  ##
  def approval_email_settings
    @user = User.find(params[:id])

    if current_user.id == @user.id && (u_comp = @user.user_company(current_company))
    else
      raise CanCan::AccessDenied
    end

    if UserCompany::APPROVAL_EMAIL_SETTINGS.values.include?(params[:email_settings])
      u_comp.approval_email_settings = params[:email_settings]
      u_comp.save

      render json: {success: true, message: t("user.approval_email_settings.success")}
    else
      render json: {success: false, message: t("user.approval_email_settings.error")}
    end
  end

  protected

  def user_params(has_perm = false)
    info = [:home_email, :password, :password_confirmation, :mark_as_read, :remind_mark_as_read_later]

    if has_perm
      info.concat([:name, :email])
    end

    params[:user].permit(info)
  end
end
