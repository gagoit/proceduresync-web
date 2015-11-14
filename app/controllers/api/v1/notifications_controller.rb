module Api
  module V1
    class NotificationsController < ApplicationController
      respond_to :json

      ## get notification
      # /api/notification.json
      # GET  
      # @params: 
      #    {noti_id, token, push_token, platform, app_access_token}
      # @response
      #    
      ##  
      def show
        if @notification = PushNotification.where(:id => params[:noti_id]).first
          if params[:token].blank?
            @error = I18n.t('user.null_or_invalid_token')
            @error_code = ERROR_CODES[:invalid_value]
            render "api/v1/shared/error"
            return false
          else
            if @token_user = get_user_from_token
              user_tags = NotificationService.user_tags(@token_user)

              #check if notification is for this user or not
              if (@notification.tags.include?(user_tags) rescue false)
              else
                @error = "This notification is not available for this user"
                @error_code = ERROR_CODES[:invalid_value]
                @debugCode = "This notification is not available for this user"
                render "api/v1/shared/error"
                return false
              end

              @user_push_tokens = @token_user.devices.where(app_access_token: params[:app_access_token]).pluck(:token)

              if @user_push_tokens.include?(params[:push_token])
                
              elsif @notification.type != "remote_wipe_device"
                #Update new push_token for user
                @token_user.push_token = params[:push_token]
                @token_user.app_access_token = params[:app_access_token]
                @token_user.platform = params[:platform]
                @token_user.device_name = params[:device_name]
                @token_user.os_version = params[:os_version]
                @token_user.save

                @user_push_tokens << params[:push_token]
              end

              ## Remove device in Pusher if notification type is remote_wipe_device
              if @notification.type == "remote_wipe_device" && @notification.devices
                @notification.devices.each do |push_token|
                  UserService.remove_user_device_in_pusher(@token_user, push_token, @notification.access_token)
                  
                  @token_user.devices.where(app_access_token: @notification.access_token, token: push_token).destroy_all
                end
              end

            else
              @error = I18n.t('user.null_or_invalid_token')
              @error_code = ERROR_CODES[:invalid_value]
              render "api/v1/shared/error"
              return false
            end
          end
        else
          @error = t("notification.id_not_found")
          @error_code = ERROR_CODES[:invalid_value]
          return render_error
        end
      end
    end
  end
end