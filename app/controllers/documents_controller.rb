class DocumentsController < ApplicationController
  before_filter :authenticate_user!

  before_filter :check_company
  before_filter :check_permission

  SORT_MAP = {
    1 => "title",
    2 => "doc_id",
    3 => "curr_version",
    4 => "created_time",
    5 => "expiry",
    6 => "restricted",
    7 => "category_name"
  }

  # GET /documents
  # GET /documents.json
  def index
    @documents = current_company.documents
    @categories = current_company.categories
    filter = params[:filter] || 'all'
    @table = {title: t("navigations.all.title_in_table"), filter: "all"}
    @table[:search] = params[:search] || ""
    types = params[:types] || "all"

    if filter == "favourite" || filter == "unread" || filter == "private" || filter == "inactive" || filter == "to_approve"
      @table[:title] = t("navigations.#{filter}.title_in_table")
      @table[:filter] = filter
    end

    if params[:category_id] && (cate = Category.where(id: params[:category_id]).first)
      if types == "accountable"
        @table[:title] = "All Accountable Documents"
      else
      end

      @table[:title] = "#{@table[:title]} in Category '#{cate.name}'"
      @table[:category_id] = cate.id
    end

    if request.xhr? && params[:iColumns]
      per_page = (params[:iDisplayLength] || OBJECT_PER_PAGE[:document]).to_i
      page = params[:iDisplayStart] ? ((params[:iDisplayStart].to_i/per_page.to_i) + 1) : 1
      params[:iSortCol_0] = 1 if params[:iSortCol_0].blank?
      sort_field = SORT_MAP[params[:iSortCol_0].to_i] || "title"
      
      @documents, total_count = Document.get_all(current_user, current_company, {
          page: page, 
          per_page: per_page, 
          search: @table[:search], 
          sort_by: [[sort_field, (params[:sSortDir_0] || "asc")]], 
          filter: @table[:filter], 
          category_id: @table[:category_id],
          types: types,
          order_by_ranking: params[:order_by_ranking]
        })

      render :json =>  Document.documents_for_datatable(current_user, current_company, @documents, total_count, @table[:filter])
      return
    end

    @u_comp = current_user.user_company(current_company, true)
    @can_add_edit_doc = PermissionService.can_add_edit_document(current_user, current_company)
    @can_bulk_assign_doc = PermissionService.can_bulk_assign_documents(current_user, current_company)
    
    @is_approver = (@table[:filter] == "to_approve" && @u_comp["is_approver"])

    respond_to do |format|
      format.html # new.html.erb
      format.json { 
        per_page = params[:per_page] || OBJECT_PER_PAGE[:document]
        page = params[:page] ? params[:page].to_i : 1

        @documents, total_count = Document.get_all(current_user, current_company, {page: page, per_page: per_page, search: @table[:search], 
                          sort_by: [:title, :asc], filter: @table[:filter], category_id: @table[:category_id], types: params[:types] || "all", order_by_ranking: params[:order_by_ranking]})

        render :json =>  {
          docs: @documents,
          docs_html: render_to_string(:partial => "documents/documents_in_dashboard", locals: {documents: @documents, doc_filter: @table[:filter]}, formats: [:html])
        }
      }
    end
  end

  # GET /documents/1
  # GET /documents/1.json
  def show
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @document }
    end
  end

  def edit
    @categories = current_company.categories

    @can_add_edit_doc = PermissionService.can_add_edit_document(current_user, current_company)
    @can_bulk_assign_doc = PermissionService.can_bulk_assign_documents(current_user, current_company)
  end

  def to_approve
    @categories = current_company.categories

    if (@is_approver = current_user.is_approver?(current_company)) || current_user.admin || current_user.super_help_desk_user
      @current_version = @document.current_version
      if @current_version && @current_version.box_view_id
        @view_url, @assets_url = @current_version.get_box_url
      end
    else
      raise CanCan::AccessDenied
    end
  end

  # GET /documents/new
  # GET /documents/new.json
  def new
    @document.curr_version = "1.0"
    @categories = current_company.categories

    if current_company.is_hybrid? 
      @document.assign_document_for = Document::ASSIGN_FOR[:approval]
    end

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @document }
    end
  end

  # POST /documents
  # POST /documents.json
  def create
    @document.need_validate_required_fields = true
    @document.belongs_to_paths = ActiveSupport::JSON.decode(params[:document][:belongs_to_paths])

    @document.created_time = BaseService.convert_string_to_time(current_company, params[:document][:created_time])
    @document.expiry = BaseService.convert_string_to_time(current_company, params[:document][:expiry]) unless params[:document][:expiry].blank?
    @document.effective_time = BaseService.convert_string_to_time(current_company, params[:document][:effective_time]) unless params[:document][:effective_time].blank?

    @document.created_by_id = current_user.id
    @version = @document.versions.new({ version: @document.curr_version, file: params[:version][:file], 
      user_id: current_user.id, file_url: params[:version][:file_url], file_name: params[:version][:file_name], 
      file_size: params[:version][:file_size].to_f, need_validate_required_fields: true})

    if @document.valid? && @version.valid?
      @document.save
      @version.save

      @message =  {
        success: true,
        message: t("document.create.success")
      }
    else
      @message = {
        success: false,
        message: @version.valid? ? @document.errors.full_messages.first : @version.errors.full_messages.first
      }

      @exist_doc = @document.same_doc(current_company)
      @message[:doc_id] = @exist_doc.id.to_s if @exist_doc
    end

    respond_to do |format|
      format.html {render json: @message,  layout: false}
      format.json {render json: @message, layout: false}
      format.js {render :layout => false}
    end
  end

  # PATCH/PUT /documents/1
  # PATCH/PUT /documents/1.json
  def update
    can_add_edit_doc = PermissionService.can_add_edit_document(current_user, current_company)

    @message =  {
      success: true,
      message: t("document.update.success")
    }

    @document.need_validate_required_fields = true
    @document.updated_by_id = current_user.id
    @version = nil
    need_update_current_version = false
    
    if can_add_edit_doc
      @document.belongs_to_paths = ActiveSupport::JSON.decode(params[:document][:belongs_to_paths])

      params[:document][:created_time] = BaseService.convert_string_to_time(current_company, params[:document][:created_time])
      params[:document][:expiry] = BaseService.convert_string_to_time(current_company, params[:document][:expiry]) unless params[:document][:expiry].blank?
      params[:document][:effective_time] = BaseService.convert_string_to_time(current_company, params[:document][:effective_time]) unless params[:document][:effective_time].blank?

      if params[:version][:file_url].blank? || params[:version][:file_name].blank?
        # no file is upload => Don't create version, just update document's info

        @message[:version_changed] = (@document.curr_version != params[:document][:curr_version])
        need_update_current_version = @message[:version_changed]
      else
        # new file is upload => Create new version, and update document's info
        @message[:version_changed] = true

        @version = @document.versions.new({version: params[:document][:curr_version], 
          need_validate_required_fields: true, document_correction: params[:document][:document_correction]})

        #@version.file = params[:version][:file] unless params[:version][:file].blank?
        @version.file_url = params[:version][:file_url] 
        @version.file_name = params[:version][:file_name] 
        @version.file_size = params[:version][:file_size].to_f
        @version.user_id = current_user.id
      end

    else
      new_paths = ActiveSupport::JSON.decode(params[:document][:belongs_to_paths])
      changed_paths = (@document.belongs_to_paths - new_paths) + (new_paths - @document.belongs_to_paths)
      
      editable_paths = PermissionService.available_areas_for_bulk_assign_documents(current_user, current_company)

      if (changed_paths - editable_paths).length > 0
        @message[:success] = false
        @message[:message] = t("error.access_denied")
      else
        @document.belongs_to_paths = new_paths
      end
    end

    if @message[:success]
      @document.attributes = document_params if can_add_edit_doc

      if @document.valid? && (@version.nil? || @version.valid?)
        @document.save
        @version.save if @version

        @message[:accountable_categories_nav] = render_to_string(:partial => "shared/accountable_categories_nav", formats: [:html])
        @message[:all_categories_nav] = render_to_string(:partial => "shared/all_categories_nav", formats: [:html])
    
        if need_update_current_version
          @document.versions.where(id: @document.current_version.try(:id)).update_all({version: params[:document][:curr_version]})
        end
      else
        @message = {
          success: false,
          message: (@version.nil? || @version.valid?) ? @document.errors.full_messages.first : @version.errors.full_messages.first
        }

        @exist_doc = @document.same_doc(current_company)
        @message[:doc_id] = @exist_doc.id if @exist_doc
      end
    end

    respond_to do |format|
      format.html {render json: @message,  layout: false}
      format.json {render json: @message, layout: false}
      format.js {render :layout => false}
    end
  end

  # PATCH/PUT /documents/1/approve
  # PATCH/PUT /documents/1/approve.json
  def approve
    @message = @document.approve!(current_user, current_company, document_params, params)

    if @message[:success]
      @message[:success_url] = documents_path(filter: "to_approve")
    else
      @exist_doc = @document.same_doc(current_company)
      @message[:doc_id] = @exist_doc.id if @exist_doc
    end

    respond_to do |format|
      format.html {render json: @message,  layout: false}
      format.json {render json: @message, layout: false}
      format.js {render :layout => false}
    end
  end

  # POST /documents/create_private_document
  # POST /documents/create_private_document.json
  def create_private_document
    @document.private_for_id = current_user.id
    @document.created_by_id = current_user.id

    while @document.title.blank? || (@exist_doc = current_company.documents.where({title: @document.title}).first)
      @document.title = "#{@document.title} #{Random.rand(100)}".strip
    end

    while @document.doc_id.blank? || (@exist_doc = current_company.documents.where({doc_id: @document.doc_id}).first)
      @document.doc_id = "#{@document.doc_id} #{Random.rand(100)}".strip
    end

    new_ver = "1.0"
    if last_version = @document.versions.first
      new_ver = (last_version.version.to_i + 1).to_s      
    end

    @version = @document.versions.new({version: new_ver, user_id: current_user.id})
    @version.file = params[:version][:file] rescue nil
    @version.file_url = params[:version][:file_url] unless params[:version][:file_url].blank?
    @version.file_name = params[:version][:file_name] unless params[:version][:file_name].blank?
    @version.file_size = params[:version][:file_size].to_f rescue 0.0

    @document.curr_version_size = @version.file_size

    while (!@version.valid? && @version.errors.include?(:version))
      @version.version = "#{@version.version} #{Random.rand(10)}"
    end

    if @document.valid? && @version.valid?
      #check private folder size of user in company
      curr_private_size = current_user.private_documents.where(:company_id => current_company.id).sum(:curr_version_size)
      max_size = current_company.private_folder_size * 1000000
      new_size = curr_private_size + @version.file_size

      if new_size > max_size
        remain_size = ((max_size - curr_private_size)/1000000.to_f).round(2)
        remain_size = 0 if remain_size < 0
        
        @message =  {
          success: false,
          message: t("document.create.error.not_enough_size")
        }
      else
        @document.save
        @version.save

        @message =  {
          success: true,
          message: t("document.create.success")
        }
      end
    else
      @message = {
        success: false,
        message: @version.valid? ? @document.errors.full_messages.first : @version.errors.full_messages.first
      }
    end

    respond_to do |format|
      format.html {render json: @message,  layout: false}
      format.json {render json: @message, layout: false}
      format.js {render :layout => false}
    end
  end

  # DELETE /documents/1
  # DELETE /documents/1.json
  def destroy
    @message =  {
      success: true,
      message: t("document.delete.success")
    }
    if(@document)
      if(current_user.private_doc?(@document))
        result = @document.destroy
        if !result
          @message[:success] = false
          @message[:message] =  @document.errors.full_messages.first
        end
      else
        @message[:success] = false
        @message[:message] = t("document.delete.error.has_no_perm")
      end
    else
       @message[:success] = false
       @message[:message] = t("document.update.error.not_found")
    end

    render json: @message

  end

  def create_category
    @category = current_company.categories.new({name: params[:category][:name]})

    if @category.save
      render json: {
        success: true,
        message: t("document.create_category.success"),
        category_id: @category.id.to_s,
        categories: render_to_string(:partial => "documents/select_categories", locals: {current_cate_id: @category.id, 
          can_add_edit_doc: true, categories: current_company.categories}, formats: [:html]),
        categories_modal: render_to_string(:partial => "documents/select_categories", locals: {current_cate_id: @category.id, 
          can_add_edit_doc: true, categories: current_company.categories, field_id: "category_id", field_name: "category[id]"}, formats: [:html]),
        accountable_categories_nav: render_to_string(:partial => "shared/accountable_categories_nav", formats: [:html]),
        all_categories_nav: render_to_string(:partial => "shared/all_categories_nav", formats: [:html])
      }
    else
      render json: {
        success: false,
        message: @category.errors.full_messages.first
      }
    end
  end

  ##
  # Edit category
  ##
  def edit_category
    @category = current_company.categories.find( params[:category][:id] )

    @category.name = params[:category][:name]

    if @category.save
      render json: {
        success: true,
        message: t("document.edit_category.success"),
        category_id: @category.id.to_s,
        categories: render_to_string(:partial => "documents/select_categories", locals: {current_cate_id: params[:document_category_id], 
          can_add_edit_doc: true, categories: current_company.categories}, formats: [:html]),
        categories_modal: render_to_string(:partial => "documents/select_categories", locals: {current_cate_id: @category.id, 
          can_add_edit_doc: true, categories: current_company.categories, field_id: "category_id", field_name: "category[id]"}, formats: [:html]),
        accountable_categories_nav: render_to_string(:partial => "shared/accountable_categories_nav", formats: [:html]),
        all_categories_nav: render_to_string(:partial => "shared/all_categories_nav", formats: [:html])
      }
    else
      render json: {
        success: false,
        message: @category.errors.full_messages.first
      }
    end
  end

  ##
  # Update category for batch documents
  ##
  def update_category
    result = Document.update_category(current_user, current_company, params)

    if result[:success]
      result[:accountable_categories_nav] = render_to_string(:partial => "shared/accountable_categories_nav", formats: [:html])
      result[:all_categories_nav] = render_to_string(:partial => "shared/all_categories_nav", formats: [:html])
    end

    render json: result
  end

  def update_name
    @message =  {
      success: true,
      message: t("document.update.success")
    }
    if(@document)
      result = @document.update_attributes({title: params[:title], updated_by_id: current_user.id})
      if !result
        @message[:success] = false
        @message[:message] =  @document.errors.full_messages.first
      end
    else
       @message[:success] = false
       @message[:message] = t("document.update.error.not_found")
    end

    render json: @message

  end

  def mark_as_read
    @result = current_user.read_document!(@document)

    if (@result[:error] rescue false)
      render json: {
        success: false,
        message: @result[:error]
      }
    else
      render json: {
        success: true,
        message: t("document.mark_as_read.success")
      }
    end
  end

  ##
  # Favourite a document
  ##
  def favourite
    if params[:type] == "favourite"
      @result = current_user.favour_document!(@document)
    elsif params[:type] == "unfavourite"
      @result = current_user.unfavour_document!(@document)
    end

    @result[:message] = t("document.#{params[:type]}.success")

    if (@result[:error] rescue false)
      render json: {
        success: false,
        message: @result[:error]
      }
    else
      render json: {
        success: true,
        message: @result[:message]
      }
    end
  end

  def export_csv
    sort_field = SORT_MAP[params[:sort_column].to_i]
    params[:sort_by] = [[sort_field, params[:sort_dir]]]

    data = Document.export_csv(current_user, current_company, params)

    respond_to do |format|
      format.html
      format.csv {
        response.headers.delete("Pragma")
        response.headers.delete('Cache-Control')
        send_data data[:file], :filename => data[:name], type: 'text/csv', disposition: 'attachment'
      }
    end
  end


  # Documents Assignment in documents page
  # Here you can bulk assign many documents to a different part of the organisation:
  # @params:
  # ids: id1,id2,id3
  # assignment_type: {String}
  #  - assign_without_approval: "Distribute document(s) without approval to the following areas"
  #  - add_accountability: "Make document (s) accountable document(s) for the following users"} Add Accountability
  #  - remove_accountability: "Make document (s) NOT accountable document(s) for the following users"} Remove Accountability
  # paths: {Array}
  def update_paths
    result = Document.update_paths(current_user, current_company, params)

    if result[:success]
      result[:accountable_categories_nav] = render_to_string(:partial => "shared/accountable_categories_nav", formats: [:html])
      result[:all_categories_nav] = render_to_string(:partial => "shared/all_categories_nav", formats: [:html])
    end

    render json: result
  end

  def logs
    if request.xhr?
      per_page = params[:iDisplayLength] || PER_PAGE
      page = params[:iDisplayStart] ? ((params[:iDisplayStart].to_i/per_page.to_i) + 1) : 1
      params[:iSortCol_0] = 1 if params[:iSortCol_0].blank?
      
      @logs = LogService.document_logs(current_user, current_company, @document, page, per_page)

      render :json =>  @logs

      return
    end

    @logs = @document.logs.includes(:target_document, :target_user).order([:action_time, :desc])

    respond_to do |format|
      format.html
      format.json { render json: @logs }
    end
  end

  ##
  # Get In the Approval web page, add an "Approval Log" widget under the "Approve Document" widget.  
  # This will only show logs relating to when a document has been approved or not approved. 
  # It should show the user name who and what sections they approved or didn't approve to. 
  ##
  def approval_logs
    if request.xhr?
      per_page = params[:iDisplayLength] || PER_PAGE
      page = params[:iDisplayStart] ? ((params[:iDisplayStart].to_i/per_page.to_i) + 1) : 1
      params[:iSortCol_0] = 1 if params[:iSortCol_0].blank?
      
      @logs = LogService.document_approval_logs(current_user, current_company, @document, page, per_page)

      render :json =>  @logs

      return
    end

    @logs = @document.approver_documents.includes(:user).order([:updated_at, :desc]).page(page).per(per_page)

    respond_to do |format|
      format.html
      format.json { render json: @logs }
    end
  end

  ##
  # Document Settings
  ##
  def settings

  end

  def save_settings
    @result = {success: true, message: t("document_settings.success"), need_remove_for_approval_nav: false}

    if params[:document_settings].is_a?(Array)
      current_company.document_settings = params[:document_settings]
    else
      current_company.document_settings = []
    end

    if PermissionService.can_edit_company_type(current_user, current_company)
      if params[:documents_have_approval] == "on" && !current_company.documents_have_approval?
        current_company.type = Company::TYPES[:hybrid]

        if current_user.admin || current_user.super_help_desk_user || (current_user.user_company(current_company, true)["is_approver"] rescue false)
          @result[:need_reload] = true
        end

      elsif params[:documents_have_approval] != "on"
        current_company.type = Company::TYPES[:standard]
        @result[:need_remove_for_approval_nav] = true
      end

    end

    current_company.save(validate: false)
  end

  protected

  def document_params
    params[:document].permit(:active, :title, :doc_id, :category_id, :created_time, :expiry, 
      :effective_time, :restricted, :curr_version, :assign_document_for, :document_correction) rescue {}
  end

  def version_params
    params[:version].permit(:version, :file, :file_name, :file_url)
  end

  def check_permission
    if ["show", "edit", "update", "mark_as_read", "update_name", "destroy", "approve", "logs", "to_approve", "favourite", "approval_logs"].include?(params[:action])
      @document = current_company.documents.find(params[:id])

      if params[:action] == "update" || params[:action] == "approve"
        @document.restricted = (params[:document] && params[:document].has_key?(:restricted)) ? params[:document][:restricted] : @document.restricted
      end

      doc = @document
    elsif (params[:action] == "create" || params[:action] == "new" || params[:action] == "create_private_document")
      @document = current_company.documents.new(document_params)

      @document.restricted = (params[:document] && params[:document].has_key?(:restricted)) ? params[:document][:restricted] : @document.restricted

      @document.is_private = (params[:document] && params[:document].has_key?(:is_private)) ? params[:document][:is_private] : @document.is_private
      @document.private_for_id = (params[:document] && params[:document].has_key?(:private_for_id)) ? params[:document][:private_for_id] : @document.private_for_id
      
      doc = @document
    else
      doc = current_company.documents.new(document_params)
      doc.restricted = (params[:document] && params[:document].has_key?(:restricted)) ? params[:document][:restricted] : false
    end

    super(doc)
  end

end
