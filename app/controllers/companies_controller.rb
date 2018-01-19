class CompaniesController < ApplicationController
  before_filter :authenticate_user!

  before_filter :check_company
  before_filter :check_permission

  # GET /companies
  # GET /companies.json
  def index
    @companies = Company.all

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @companies }
    end
  end

  # GET /companies/1
  # GET /companies/1.json
  def show

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @company }
    end
  end

  # POST /companies
  # POST /companies.json
  def create

    if @company.save
      render json: @company, status: :created, location: @company
    else
      render json: @company.errors
    end
  end

  # PATCH/PUT /companies/1 "Sorry, There are something errors."
  # PATCH/PUT /companies/1.json
  def update
    @message = {}
    @company.updated_by_id = current_user.id.to_s

    if @company.update(company_params)
      @message = {status: "success", success: true, message: "Company has been updated successfully.", image_src: @company.logo}

      if company_params[:credit_card_number]
        @message[:credit_card_number] = @company.credit_card_number
      end
    else
      @message = {status: "danger", success: false, message: @company.errors.full_messages.first, image_src: @company.logo}
    end

    respond_to do |format|
      format.html {render json: @message,  layout: false}
      format.json
      format.js {render :layout => false}
    end

  end

  # DELETE /companies/1
  # DELETE /companies/1.json
  def destroy
    #@company.destroy

    head :no_content
  end

  # GET /companies/1/structure
  # GET /companies/1/structure.json
  def structure

  end

  def compliance
    @company_table_structure = current_company.table_structure(["company"])
  end

  # PATCH/POST /companies/1/add_org_node
  # PATCH/POST /companies/1/add_org_node.json
  # params : {
  #   parent_id: ,
  #   parent_type: ,
  #   name:
  # }
  def add_org_node
    begin
      parent_type = params[:parent_type]

      parent = @company.company_structures.where(type: parent_type).find(params[:parent_id])

      child_type = Company::STRUCTURES[parent_type.to_sym][:child]

      child = parent.childs.create({ name: params[:name], type: child_type, company_id: @company.id, updated_by_id: current_user.id.to_s })

      if child.valid?
        obj_name = @company.try("#{child_type}_label".to_sym) || child_type.titleize

        changes = {"node_name" => params[:name], "node_id" => child.id, "node_type" => child_type}
        @company.create_logs({user_id: current_user.id, action: ActivityLog::ACTIONS[:created_organisation_structure], attrs_changes: changes})

        current_company.reload

        render json: {  success: true, name: child.name, id: child.id.to_s, message: "#{obj_name} has been created successfully",
                        new_replicate_accountable_documents_html: render_to_string(:partial => "companies/replicate_accountable_documents", formats: [:html])
                      }
      else
        render json: {success: false, message: child.errors.full_messages.first}
      end
    rescue Exception => e
      puts e.message

      render json: {success: false, message: e.message}
    end
  end

  # PATCH/PUT /companies/1/update_org_node
  # PATCH/PUT /companies/1/update_org_node.json
  # params : {
  #   node_id: ,
  #   node_type: ,
  #   name:
  # }
  def update_org_node
    begin
      node_type = params[:node_type]

      node = @company.company_structures.where(type: node_type).find(params[:node_id])

      changes = {}
      if node && node.name != params[:name]
        changes = {"node_name" => [node.name, params[:name]], "node_id" => node.id, "node_type" => node_type}
      end

      if node.update({ name: params[:name] })
        obj_name = @company.try("#{node_type}_label".to_sym) || node_type.titleize

        @company.create_logs({user_id: current_user.id, action: ActivityLog::ACTIONS[:updated_organisation_structure], attrs_changes: changes}) unless changes.blank?
        
        current_company.reload
        
        render json: {  success: true, name: node.name, id: node.id.to_s, message: "#{obj_name} has been updated successfully",
                        new_replicate_accountable_documents_html: render_to_string(:partial => "companies/replicate_accountable_documents", formats: [:html])
                      }
      else
        render json: {success: false, message: node.errors.full_messages.first}
      end
    rescue Exception => e
      puts e.message

      render json: {success: false, message: e.message}
    end
  end

  # PATCH/GET /companies/1/load_childs_of_org_node
  # PATCH/GET /companies/1/load_childs_of_org_node.json
  # params : {
  #   node_id: ,
  #   node_type:
  # }
  def load_childs_of_org_node
    begin
      node_type = params[:node_type]

      if node_type == 'company'
        node = @company.company_structures.find_or_create_by(type: node_type)
      else
        node = @company.company_structures.where(type: node_type).find(params[:node_id])
      end

      partial = "companies/child_td_in_table"

      if params[:compliance]
        partial = "companies/child_td_in_table_for_compliance"
      end

      render json: {
        success: true,
        name: node.name,
        id: node.id.to_s,
        childs_count: node.childs.count,
        childs_html: render_to_string(:partial => partial, locals: {childs: node.childs, parent: node}, formats: [:html])
      }
    rescue Exception => e
      puts e.message

      render json: {success: false, message: e.message}
    end

    return
  end

  # PATCH/GET /companies/1/preview_company_structure
  # PATCH/GET /companies/1/preview_company_structure.json
  # params : {
  # }
  def preview_company_structure
    render json: {
      success: true,
      tree_data: @company.tree_structure
    }
  end


  def replicate_accountable_documents
    result = CompanyService.validate_replicate_accountable_documents(current_company, params, updated_by_id: current_user.id)
    render json: result
  end


  def logs
    if request.xhr?
      per_page = params[:iDisplayLength] || PER_PAGE
      page = params[:iDisplayStart] ? ((params[:iDisplayStart].to_i/per_page.to_i) + 1) : 1
      params[:iSortCol_0] = 1 if params[:iSortCol_0].blank?
      
      @logs = LogService.company_logs(current_user, current_company, page.to_i, per_page.to_i, params[:search])

      render :json =>  @logs

      return
    end

    respond_to do |format|
      format.html
      format.json { 
        @logs = current_company.logs.includes(:target_document, :target_user).order([:action_time, :desc])
        render json: @logs 
      }
    end
  end

  def invoices
    if request.xhr?
      # per_page = params[:iDisplayLength] || PER_PAGE
      # page = params[:iDisplayStart] ? ((params[:iDisplayStart].to_i/per_page.to_i) + 1) : 1
      params[:iSortCol_0] = 1 if params[:iSortCol_0].blank?
      
      @invoices = CompanyService.invoices(current_user, current_company)

      render :json =>  @invoices

      return
    end

    respond_to do |format|
      format.html
      format.json { 
        @invoices = CompanyService.invoices(current_user, current_company)
        render json: @invoices 
      }
    end
  end

  ##
  # Super Admin Generate invoice for a company in previous months
  ##
  def generate_invoice
    current_company.generate_invoice

    render json: {
      success: true,
      message: "Company has been generated invoice successfully"
    }
  end

  ##
  # 
  ##
  def load_company_structure_table
    editable_paths = current_company.all_paths_hash.keys

    if params.has_key?(:user_id)
      user = current_company.users.where(id: params[:user_id]).first
      u_comp = user.try(:user_company, current_company)

      if params[:table_id].to_s.include?("approver")
        current_paths = (u_comp.try(:approver_path_ids) || [])
      elsif params[:table_id].to_s.include?("supervisor")
        current_paths = (u_comp.try(:supervisor_path_ids) || [])
      else
        current_paths = []
      end

    elsif params.has_key?(:document_id)
      document = current_company.documents.where(id: params[:document_id]).first
      current_paths = document.try(:belongs_to_paths) || []

      if params[:type] == "to_approve"
        current_paths = PermissionService.approver_can_approve_document_for_areas(current_user, current_company, document)
      end

      if params[:type] == "edit_document"
        editable_paths = PermissionService.available_areas_for_bulk_assign_documents(current_user, current_company)
      else
        editable_paths = current_paths
      end

    else
      if params[:type] == "bulk_assignment"
        editable_paths = PermissionService.available_areas_for_bulk_assign_documents(current_user, current_company)
      end
       
      current_paths = []
    end

    partial = "shared/company_structure_table"

    if params[:compliance]
      partial = "shared/company_structure_table_for_compliance"
    end
    
    render json: {
      success: true,
      company_structure_table_html: render_to_string(:partial => partial, 
          :locals => {
              company_table_structure: current_company.table_structure(["company"]), 
              current_paths: current_paths, 
              editable_paths: editable_paths,
              table_id: params[:table_id], expanded: params[:expanded], compliance: params[:compliance]}, formats: [:html])
    }
  end


  def load_delete_section_modal
    node = @company.company_structures.where(type: params[:node_type]).find(params[:node_id])
    node_reference = Companies::GetReferenceInfoOfSection.call(@company, node.path)
    can_delete = node_reference[:active_users_count] == 0

    sections = []
    @company.company_structures.where(path: /#{node.path}/).order([:path, :asc]).each do |n|
      if n.child_ids.length == 0
        sections << {
          id: n.id,
          name: @company.all_paths_hash[n.path],
          path: n.path
        }
      end
    end

    render json: {
      success: true,
      modal_body_html: render_to_string(
        partial: "confirm_clean_sections_modal_body", 
        locals: {
          can_delete: can_delete,
          users: node_reference[:active_users].map { |e| e.user },
          sections: sections
        },
        formats: [:html],
        locale: [:en],
        handlers: [:haml]
      )
    }
  end

  def delete_section
    node = @company.company_structures.where(type: params[:node_type]).find(params[:node_id])
    result = Companies::DeleteSections.call current_user, @company, node.id, node.type
    
    render json: result
  end

  protected

  def company_params
    params[:company].permit(:name, :suburb_city, :state_district, :country, :phone, :fax, :abn_acn, :invoice_email, 
      :credit_card_number, :name_on_card, :card_expiry, :card_ccv, :address, :logo)
  end

  def check_permission
    return true if params[:action] == "logs"

    if params[:action] == "create"
      @company = Company.new(params[:company])
      comp = @company

    elsif params[:id]
      @company = Company.find(params[:id])
      comp = @company

    else
      comp = Company.new

    end

    super(comp)
  end
end
