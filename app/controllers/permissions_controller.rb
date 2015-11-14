class PermissionsController < ApplicationController
  before_filter :authenticate_user!

  before_filter :check_company
  before_filter :check_permission
  # GET /permissions
  # GET /permissions.json
  def index
    @permissions = current_company.standard_permissions
  end

  # GET /permissions/1
  # GET /permissions/1.json
  def show
    @permission = Permission.find(params[:id])

    render json: @permission
  end

  # POST /permissions
  # POST /permissions.json
  def create
    @permission = current_company.permissions.new({name: params[:permission][:name]})

    if @permission.save
      current_company.create_logs({user_id: current_user.id, action: ActivityLog::ACTIONS[:created_permission], attrs_changes: {"perm_name" => params[:permission][:name]}})

      render json: {
        success: true,
        tr_new_html: render_to_string(:partial => "permissions/permission_in_table", locals: {permission: @permission}, formats: [:html]),
        message: "Permission has been created successfully."
      }, status: :created, location: @permission
    else
      render json: {
        success: false,
        message: @permission.errors.full_messages.first
      }
    end
  end

  # PATCH/PUT /permissions/update_batch
  # PATCH/PUT /permissions/update_batch.json
  def update_batch
    result = Permission.update_batch(current_user, current_company, params[:permissions])
    if result[:success]
      render json: {
        success: true,
        message: "Permissions have been updated successfully."
      }
    else
      render json:  {
        success: false,
        message: result[:error]
      }
    end
  end

  # PATCH/PUT /permissions/1
  # PATCH/PUT /permissions/1.json
  def update
    @permission = current_company.permissions.find(params[:id])

    if @permission.update(params[:permission].permit())
      render json: {
        success: true,
        message: "Permission has been updated successfully."
      }
    else
      render json: {
        success: false,
        message: @permission.errors.full_messages.first
      }
    end
  end

  # DELETE /permissions/1
  # DELETE /permissions/1.json
  def destroy
    @permission = current_company.permissions.find(params[:id])
    #@permission.destroy

    head :no_content
  end

  protected

  def check_permission
    super(current_company.permissions.new)
  end
end
