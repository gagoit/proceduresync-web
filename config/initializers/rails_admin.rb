require 'rails_admin_bulk_upload'
require 'rails_admin/config/actions/rails_admin_delete'
require 'csv_converter'
require 'rails_admin_notify'
require 'rails_admin_generate_invoice'

RailsAdmin.config do |config|

  ### Popular gems integration
  config.main_app_name = ['Proceduresync', 'Admin']
  ## == Devise ==
  # config.current_user_method { current_user } # auto-generated
  config.authenticate_with do
    warden.authenticate! scope: :user
  end
  config.current_user_method &:current_user
  config.authorize_with :cancan

  config.compact_show_view = false

  ## == PaperTrail ==
  # config.audit_with :paper_trail, 'User', 'PaperTrail::Version' # PaperTrail >= 3.0.0

  ### More at https://github.com/sferik/rails_admin/wiki/Base-configuration

  config.navigation_static_links = {
    'Website Dashboard' => "/dashboard"
  }

  config.actions do
    dashboard                     # mandatory
    index                         # mandatory
    new
    export
    bulk_delete

    show
    edit
    delete
    show_in_app

    bulk_upload
    #generate_invoice
    ## With an audit adapter, you can add:
    # history_index
    # history_show

    config.model User do
      edit do
        field :companies
        field :name, :string
        field :email, :string
        field :home_email, :string
        field :password, :password
        field :password_confirmation, :password
        field :token, :string

        field :active do
          visible do
            bindings[:view]._current_user.admin?
          end
        end
        field :has_setup
        field :push_token, :string
        field :app_access_token, :string
        
        field :platform, :enum do
          enum do
            UserDevice::PLATFORMS.values
          end
        end

        field :device_name, :string
        field :os_version, :string

        field :admin do
          visible do
            bindings[:view]._current_user.admin?
          end
        end

        field :super_help_desk_user do
          visible do
            bindings[:view]._current_user.admin?
          end
        end

        field :updated_by_id do
          visible true
          default_value do
            bindings[:view]._current_user.id
          end

          help ''
        end

        field :updated_by_admin do
          visible false
          default_value do
            true
          end

          help ''
        end
      end

      list do
        [:name, :token, :companies, :favourite_documents, :read_documents, :email, :home_email, :created_documents, :admin].each{|f| field f}
      end
    end

    config.model Document do

      list do
        [:company, :doc_id, :title, :category, :expiry, :active, :versions, :favourited_users, :read_users, :created_by, :is_private].each{|f| field f}
      end

      edit do
        field :company do
          read_only true
        end

        field :title, :string
        field :doc_id, :string do
          help ''
        end

        field :created_time
        field :expiry do
          help ''
        end

        field :active

        field :category

        configure :created_by do
          visible false
        end

        field :created_by_id, :hidden do
          visible true
          default_value do
            bindings[:view]._current_user.id
          end

          help ''
        end

        field :private_for do
          help 'Required when you check this document is private'
        end

        field :is_private do
          help 'When you check it, you have to select user who the document will be private for'
        end

        field :need_validate_required_fields, :hidden do
          visible false
          default_value do
            true
          end

          help ''
        end
      end
    end

    config.model Version do

      list do
        sort_by :created_time, :desc
        [:document, :version, :doc_file, :user, :created_time].each{|f| field f}
      end

      edit do
        field :document do
          read_only do
            !bindings[:object].new_record?
          end
        end

        field :version, :string do
          help ''
        end

        field :file

        field :need_validate_required_fields, :hidden do
          visible false
          default_value do
            true
          end

          help ''
        end
      end
    end

    config.model Company do

      list do
        sort_by :created_at, :desc
        [:name, :type, :users, :documents, :created_at].each{|f| field f}
      end

      edit do
        field :logo

        [:name, :address, :suburb_city, :state_district, :country, :phone, :fax, :abn_acn, :invoice_email, 
          :credit_card_number, :name_on_card].each do |f|
          field f, :string
        end

        field :card_expiry, :string do
          help "Format MM/YYYY"
        end

        field :card_ccv, :string

        field :saasu_contact_id

        [:company_label, :division_label, :department_label, :group_label, :depot_label, :panel_label].each{|f| field f, :string}

        field :type, :enum do
          enum do
            Company::TYPES.values
          end
        end
        
        field :is_trial
        field :trial_expiry
        field :active

        field :path_updated_at do
          help 'Updated time for Organisation structure'
        end

        field :users

        field :timezone, :enum do
          enum do
            ActiveSupport::TimeZone.all.map{|e| [e.to_s, e.name]}
          end
        end

        field :price_per_user do
          help "AUD"
        end

        field :private_folder_size do
          help "The limited size of the private folder for each user (MB)"
        end

        field :updated_user_id, :hidden do
          visible false
          default_value do
            bindings[:view]._current_user.id.to_s
          end

          help ''
        end
      end
    end

    config.model CompanyStructure do

      list do
        sort_by :created_at, :desc
        [:type, :name, :parent, :childs, :company, :created_at].each{|f| field f}
      end

      edit do
        field :name, :string
        field :type do
          read_only true
        end

        field :company do
          read_only true
        end

        field :parent do 
          read_only true
        end

        field :childs do 
          read_only true
        end

        field :updated_user_id, :hidden do
          visible false
          default_value do
            bindings[:view]._current_user.id.to_s
          end

          help ''
        end
      end
    end

    config.model UserCompany do

      list do
        sort_by :created_at, :desc
        [:user, :company, :permission, :user_type, :is_approver, :is_supervisor, :created_at].each{|f| field f}
      end

      edit do
        [:user, :company].each do |f|
          field f do
            read_only true
          end
        end
        
        field :permission
        [:company_path_ids, :approver_path_ids, :supervisor_path_ids].each do |f|
          field f do
            read_only true
          end
        end
      end
    end

    config.model Permission do
      configure :company do
        read_only true
      end

      configure :code do
        visible false
      end

      list do
        sort_by :created_at, :desc
        exclude_fields [:_id, :updated_at, :code]
      end

      edit do
        exclude_fields [:code, :is_custom]

        field :updated_user_id, :hidden do
          visible false
          default_value do
            bindings[:view]._current_user.id.to_s
          end

          help ''
        end
      end
    end

    config.model Category do

      list do
        sort_by :created_at, :desc
        [:name, :documents, :created_at].each{|f| field f}
      end

    end

    config.model ActivityLog do

      list do
        sort_by :action_time, :desc
        [:company, :user, :action, :target_document, :target_user, :action_time].each{|f| field f}
      end

    end

    config.model UserDevice do

      list do
        exclude_fields :created_at, :_id
      end

      edit do
        field :user

        field :token

        field :platform, :enum do
          enum do
            UserDevice::PLATFORMS.values
          end
        end

        field :device_name, :string
        field :os_version, :string

        field :app_access_token, :string

        field :enabled
      end
    end

    config.model Invoice do

      list do
        [:company, :month, :year, :num_of_active_users, :price_per_user, :total_amount].each do |f|
          field f
        end
        
      end
    end

    config.model ImportUser do
      configure :result do
        pretty_value do
          obj = bindings[:object]
          %{<div class="blah">
              #{obj.format_result}
            </div >}.html_safe
        end

        read_only true # won't be editable in forms (alternatively, hide it in edit section)
      end

      show do
        field :company
        field :file
        field :status
        field :result
      end

    end

    config.model StaticFile do

      configure :name do
        pretty_value do
          obj = bindings[:object]

          I18n.t("static_files.#{obj.name}")
        end
      end

      list do
        sort_by :updated_at, :desc
        [:name, :box_view_id, :box_status, :doc_file, :updated_at].each{|f| field f}
      end

      edit do

        field :name, :enum do
          enum do
            StaticFile::FILE_NAMES.map { |e| [I18n.t("static_files.#{e}"), e] }
          end
        end

        field :file
      end
    end

    config.model AppError do

      list do
        sort_by :updated_at, :desc
        [:company, :type, :message, :status, :note, :created_at, :updated_at].each{|f| field f}
      end

      edit do
        field :status, :enum do
          enum do
            AppError::STATUSES.values.map { |e| [e.to_s.titleize, e] }
          end
        end

        field :note
      end
    end

    config.model TestSite do

      list do
        sort_by :updated_at, :desc
        [:type, :name, :code, :url, :info, :created_at, :updated_at].each{|f| field f}
      end

      edit do
        field :type, :enum do
          enum do
            ["box_view"].map { |e| [e.to_s.titleize, e] }
          end
        end

        field :name
        field :code

        field :info
      end
    end
  end
end
