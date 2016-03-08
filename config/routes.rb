Proceduresync::Application.routes.draw do

  #Documents
  match "api/docs" => "api/v1/documents#index", via: :get
  match "api/docs/favourite" => "api/v1/documents#favourite", via: :post
  match "api/docs/unfavourite" => "api/v1/documents#unfavourite", via: :post
  match "api/docs/mark_as_read" => "api/v1/documents#mark_as_read", via: :post
  match "api/docs/mark_all_as_read" => "api/v1/documents#mark_all_as_read", via: :post

  ## Category
  match "api/categories" => "api/v1/categories#index", via: :get
  match "api/category/docs" => "api/v1/categories#docs", via: :get

  ## Report
  match "api/reports" => "api/v1/reports#index", via: :get
  match "api/companies" => "api/v1/reports#companies", via: :get

  ## User
  match "api/user" => "api/v1/users#show", via: :get

  match "api/user" => "api/v1/users#update", via: :put

  match "api/user/token" => "api/v1/users#token", via: :post

  match "api/user/forgot_password" => "api/v1/users#forgot_password", via: :post

  match "api/user/sync_docs" => "api/v1/users#sync_docs", via: :get

  match "api/user/docs" => "api/v1/users#docs", via: :get

  match "api/user/logout" => "api/v1/users#logout", via: :post

  match "api/notification" => "api/v1/notifications#show", via: :get

  #Checking
  match "is_alive" => "application#is_alive", via: :get

  #redirect url for app
  match "signin" => "application#signin", via: :get, as: 'signin'

  devise_for :users, :controllers => { :sessions => "sessions", registrations: "registrations", passwords: "passwords"}

  resources :users do
    member do
      get :setup
      get :profile
      get :load_more_unread_docs
      get :notifications
      get :logs
      get :devices
      post :remote_wipe_device, defaults: {format: :json}
      post :mark_all_as_read, defaults: {format: :json}

      post :sent_test_notification, defaults: {format: :json}

      post :approval_email_settings, defaults: {format: :json}

      get :login_as
    end

    collection do
      get :check_login_before
      put :change_company_view
      put :update_path
      get :export_csv
      get :load_permsions_for_user_type, defaults: {format: :json}
      post :favourite_docs, defaults: {format: :json}
    end
  end

  resources :companies do
    member do
      get :structure
      post :add_org_node

      put :update_org_node

      get :load_childs_of_org_node

      get :preview_company_structure
      get :logs

      get :invoices

      post :generate_invoice, defaults: {format: :json}

      get :load_company_structure_table, defaults: {format: :json}

      put :replicate_accountable_documents, defaults: {format: :json}

      get :compliance
    end
  end

  resources :permissions do
    collection do
      put :update_batch
    end
  end

  resources :documents do
    collection do
      post :create_category, defaults: {format: :json}
      post :update_category #, defaults: {format: :json}
      post :export_csv, defaults: {format: :json}
      post :update_paths, defaults: {format: :json}

      post :create_private_document

      get :settings
      post :save_settings

      post :edit_category, defaults: {format: :json}
    end

    member do
      get :to_approve
      post :approve, defaults: {format: :json}
      get :logs
      post :update_name
      post :mark_as_read, defaults: {format: :json}
      post :favourite, defaults: {format: :json}
      
      get :approval_logs
    end
    
    resources :versions do 
      get :download_pdf, :on => :member
    end
  end

  resources :reports do
    collection do
      get :view
      put :update_setting
      get :view_accountable_report
      get :view_supervisors_approvers_report
    end
  end

  resources :notifications, only: [:index] do
  end

  match "dashboard" => "home#dashboard", via: :get, as: "dashboard"
  match "support" => "home#support_login", via: :get, as: "support"
  match "administrator_contact" => "home#administrator_contact", via: :get, as: "administrator_contact"

  match "static_files" => "home#static_files", via: :get, as: "static_files"

  mount RailsAdmin::Engine => '/admin', :as => 'rails_admin'

  #root :to => 'home#index'
  devise_scope :user do
    root :to => 'devise/sessions#new'
  end

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
