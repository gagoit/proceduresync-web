class ReportsController < ApplicationController
  before_filter :authenticate_user!

  before_filter :check_company
  
  def index
    if current_user.admin || current_user.super_help_desk_user || 
        (u_comp = current_user.user_company(current_company))

      @report_setting = current_user.report_settings.find_or_initialize_by({company_id: current_company.id})
    else
      @report_setting = nil
    end
  end

  # params:
  #   report_setting : { 
  #      frequency
  #      users 
  #      doc_status
  #      categories
  #    }  
  def update_setting
    result = {success: true, message: ""}
    if current_user.admin || current_user.super_help_desk_user || 
        (u_comp = current_user.user_company(current_company))

      @report_setting = current_user.report_settings.find_or_create_by({company_id: current_company.id})

      cate_ids = current_company.documents.pluck(:category_id).uniq.map { |e| e.to_s }
      valid_user_ids = ReportService.report_user_ids(current_user, current_company).map { |e| e.to_s }

      can_add_edit_doc = PermissionService.can_add_edit_document(current_user, current_company, u_comp)

      if !can_add_edit_doc && params[:report_setting].has_key?(:areas)
        result[:success] = false
        result[:message] = t("error.access_denied")
      end

      if params[:report_setting].has_key?(:areas) && params[:report_setting][:areas] != ReportSetting::SELECT_USERS_TEXT
        params[:report_setting][:users] = ["all"]
      end      

      if params[:report_setting][:users].blank? || (!params[:report_setting][:users].include?("all") && !params[:report_setting][:users].include?("my_team") && (params[:report_setting][:users] - valid_user_ids).length > 0)
        result[:success] = false
        result[:message] = "Users are invalid"
      end

      if params[:report_setting][:categories].blank? || (!params[:report_setting][:categories].include?("all") && (params[:report_setting][:categories] - cate_ids).length > 0)
        result[:success] = false
        result[:message] = result[:message].blank? ? "Categories are invalid" : "#{result[:message]}, Categories are invalid"
      end

      if result[:success]
        if @report_setting.update_attributes(report_setting_params)
          result[:message] = "Emailed Report Settings has been updated successfully"
        else
          result[:success] = false
          result[:message] = @report_setting.errors.full_messages.first
        end
      end
    else
      @report_setting = nil
    end

    respond_to do |format|
      format.html
      format.json { render :json => result }
    end
  end

  ##
  # params:
  #   report : { 
  #      users 
  #      doc_status
  #      categories
  #    }  
  ##
  def view
    data = ReportService.get_report(current_user, current_company, params[:report])

    respond_to do |format|
      format.html
      format.csv {
        if data
          response.headers.delete("Pragma")
          response.headers.delete('Cache-Control')
          send_data data[:file], :filename => data[:name], type: 'text/csv', disposition: 'attachment'
        else
          redirect_to reports_path, {alert: "Data not found"}
        end
      }
    end
  end

  ##
  # params:
  #   report : { 
  #      part_of_org
  #    }  
  ##
  def view_accountable_report
    data = ReportService.get_accountable_report(current_user, current_company, params[:accountability_report])

    respond_to do |format|
      format.html
      format.csv {
        if data
          response.headers.delete("Pragma")
          response.headers.delete('Cache-Control')
          send_data data[:file], :filename => data[:name], type: 'text/csv', disposition: 'attachment'
        else
          redirect_to reports_path, {alert: "Data not found"}
        end
      }
    end
  end

  ##
  # params:
  #   report : { 
  #      part_of_org
  #    }  
  ##
  def view_supervisors_approvers_report
    data = ReportService.get_supervisors_approvers_report(current_user, current_company, params[:supervisors_approvers_report])

    respond_to do |format|
      format.html
      format.csv {
        if data
          response.headers.delete("Pragma")
          response.headers.delete('Cache-Control')
          send_data data[:file], :filename => data[:name], type: 'text/csv', disposition: 'attachment'
        else
          redirect_to reports_path, {alert: "Data not found"}
        end
      }
    end
  end

  protected

  def report_setting_params
    automatic_email = (params[:report_setting][:automatic_email] == "on")
    params[:report_setting].permit(:frequency, :doc_status, :areas, :categories => [], :users => []).merge!({is_default: false, automatic_email: automatic_email})
  end
end