module Api
  module V1
    class UsersController < ApplicationController
      respond_to :json

      before_filter :token_required, :only => [:index, :update, :sync_docs, :docs, :show, :logout]

      before_filter :company_required, :only => [:sync_docs, :docs]

      ##
      # Sign In /user/token.json POST  
      # @params:
      #    email, password 
      # @response:
      # {  
      #    uid, name, token, has_setup, home_email, email, total_docs_size, has_reset_pass,
      #    companies: [
      #       name,
      #       uid,
      #       logo_url
      #    ]
      # }
      # @error response:
      #    {error:{message,error_code,debugDesc:{}}}
      ##
      def token
        if @user = User.where(email_downcase: params[:email].to_s.downcase).first
          if !params[:password].blank?
            unless @user.valid_password?(params[:password])
              @error = t("user.password_invalid")
              @error_code = ERROR_CODES[:invalid_value]
              return render_error
            end
          else
            @error = t("user.password_invalid")
            @error_code = ERROR_CODES[:invalid_value]
            return render_error
          end

          unless (@user.active && @user.companies.active.length > 0)
            @error = @user.active ?  t("company.is_inactive") : t("user.disabled")
            @error_code = ERROR_CODES[:user_is_inactive]
            return render_error
          end
        else
          @error = t("user.email_not_found")
          @error_code = ERROR_CODES[:item_not_found]
          return render_error
        end
      end

      ##
      # Sign out /user/logout.json POST  
      # @params:
      #    token, push_token, platform, app_access_token
      # @response:
      # {  
      #    
      # }
      # @error response:
      #    {error:{message,error_code,debugDesc:{}}}
      ##
      def logout
        @user.devices.where(:token => params[:push_token], app_access_token: params[:app_access_token]).destroy_all

        NotificationService.delay.register_device(@user, params[:push_token], params[:app_access_token], false)
      end

      #forgot password
      # /user/forgot_password.json
      # POST  
      # @params: 
      #   {email}
      # @response: 
      #   {result:true}
      #
      def forgot_password
        if @user = User.where(email_downcase: params[:email].to_s.downcase).first
          unless (@user.active && @user.company_ids.length > 0)
            @error = t("user.disabled")
            @error_code = ERROR_CODES[:user_is_inactive]
            render "api/v1/shared/error"
            return false
          end
          @user.reset_password!
        else
          @error = t("user.email_not_found")
          @error_code = ERROR_CODES[:item_not_found]
          return render_error
        end
      end


      #Update Account  
      # /user.json  
      # PUT  
      # @params: 
      #   {push_token, home_email, password, app_access_token}
      # @response: 
      #   {result: true}
      def update
        params[:password_confirmation] = params[:password]
        params[:has_setup] = true

        @user.update_attributes(user_params.except(:token))

        unless @user.valid?
          @error = @user.errors.full_messages.first
          @error_code = ERROR_CODES[:invalid_value]
          return render_error
        end

        @user.reload
      end

      #Show Account  
      # /user.json  
      # GET  
      # @params: 
      #   {token}
      # @response: 
      #   User's info
      def show

      end

      # Sync docs for a user
      # /user/sync_docs.json
      # GET
      # @params: 
      #   { token, 
      #     company_id, mark_as_read, after_timestamp, 
      #     synced_doc_ids: "doc1_id,doc2_id" 
      #   }
      #    
      # @response: 
      #   {
      #     docs: [
      #       { uid, title, doc_file, version, is_unread, is_inactive, is_favourite, category  }
      #     ],
      #     last_timestamp:
      #   }
      def sync_docs
        @new_docs = @user.new_docs(@company, params)
        
        @current_time = Time.now.utc
        u_c = @user.user_company(@company)
        u_c.update_attributes({last_sync: @current_time})

        if params[:mark_as_read] == "true" && !@new_docs.blank?
          @user.read_document_ids += @new_docs.pluck(:id)
          @user.read_document_ids.uniq!
          @user.save
        end

        @docs_need_remove_in_app = @user.docs_need_remove_in_app(@company, params)
      end

      ##
      # Get Docs in a list (favourite / unread / private)
      # /user/docs.json
      # GET
      # @params: 
      #   token, filter = unread / favourite / private
      # @response:  
      #   { 
      #     docs: [ 
      #        { uid, title, doc_file, version,  is_unread, is_inactive } 
      #     ], 
      #     unread_number 
      #   }
      def docs
        @result = @user.docs(@company, params[:filter])
      end

      private

      def user_params
        params.permit(:name, :push_token, :home_email, :password, :password_confirmation, 
          :has_setup, :platform, :app_access_token, :device_name, :os_version)
      end
    end
  end
end
