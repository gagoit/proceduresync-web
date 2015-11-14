require 'rails_admin/config/actions'
require 'rails_admin/config/actions/base'

module RailsAdminBulkUpload
end

module RailsAdmin
  module Config
    module Actions
      class BulkUpload < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)
              
        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:put, :get, :patch]
        end
        
        register_instance_option :visible? do 
         authorized? && (bindings[:abstract_model].to_s ==  'Company')
        end
        
        register_instance_option :link_icon do
          'icon-upload' 
        end
        
        register_instance_option :controller do
          Proc.new do
            if request.get?
              render @action.template_name
            elsif request.put? || request.patch?
              
              csv_content_types = ["application/octet-stream", "text/csv"]
              if params[:company] && (param_file = params[:company][:users]) && 
                param_file.original_filename.index(".csv") && csv_content_types.include?(param_file.content_type)

                notice = t("admin.flash.successful", :name => @model_config.label, :action => t("admin.actions.#{@action.key}.done"))
                
                #Copy the  CSV to safety places
                #new_filename = File.join(Rails.root, 'tmp', "bulk_upload-#{Time.now.to_i}-#{param_file.original_filename}") 
                #FileUtils.cp(param_file.try(:path), new_filename)
                import_user = @object.import_users.create({file: param_file})
                UserService.delay.bulk_create(@object, import_user, current_user)
                
                redirect_to rails_admin.show_path(model_name: 'import_user', id: import_user.id), :flash => { :success => notice }
              else
                handle_save_error :bulk_upload
              end
            end
          end
        end

        
        
      end
    end
  end
end