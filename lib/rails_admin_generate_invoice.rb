require 'rails_admin/config/actions'
require 'rails_admin/config/actions/base'

module RailsAdminGenerateInvoice
end

module RailsAdmin
  module Config
    module Actions
      class GenerateInvoice < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)
      
        register_instance_option :http_methods do
          [:get, :post]
        end
        register_instance_option :visible? do        
          authorized? && (bindings[:abstract_model].to_s ==  'Company')
        end
        
        # http://twitter.github.com/bootstrap/base-css.html#icons
        register_instance_option :link_icon do
          'icon-bell'
        end        

        register_instance_option :member do
          true
        end
        
        register_instance_option :controller do
          Proc.new do
            if request.get?
              @object.generate_invoice

              notice = t("admin.flash.successful", :name => @model_config.label, :action => t("admin.actions.#{@action.key}.done"))
              
              respond_to do |format|
                format.html { redirect_to rails_admin.index_path('company'), :flash => { :success => notice } }
                format.js { render :json => { :id => @object.id.to_s, :label => @model_config.with(:object => @object).object_label } }
              end
            elsif request.post?
              @object.generate_invoice unless params[:generate_invoice].blank?
              
              respond_to do |format|
                format.html { redirect_to_on_success }
                format.js { render :json => { :id => @object.id.to_s, :label => @model_config.with(:object => @object).object_label } }
              end
            end
          end
        end
      end
    end
  end
end

