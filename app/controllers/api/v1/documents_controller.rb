module Api
  module V1
    class DocumentsController < ApplicationController
      respond_to :json

      before_filter :token_required, :only => [:favourite, :unfavourite, :mark_as_read, :index, :mark_all_as_read]

      before_filter :company_required, :only => [:favourite, :unfavourite, :mark_as_read, :index]

      before_filter :document_required, :only => [:favourite, :unfavourite, :mark_as_read]

      ##
      # Mark a doc as favourite
      # /docs/favourite.json
      # POST
      # @params: 
      #   token, company_id, doc_id, type = favourite / unfavourite, action_time
      # @response:  
      #   {result: true, is_favourite}
      def favourite
        if params[:type] == "favourite"
          @result = @user.favour_document!(@doc, params[:action_time])
        elsif params[:type] == "unfavourite"
          @result = @user.unfavour_document!(@doc, params[:action_time])
        else
          @result = {error: t("document.wrong_type_param"), error_code: ERROR_CODES[:missing_parameters]}
        end

        if (@result[:error] rescue false)
          @error = @result[:error]
          @error_code = @result[:error_code]
          return render_error
        end
      end

      ##
      # Remove doc from favourites list
      # /docs/unfavourite.json
      # POST
      # @params: 
      #   doc_id
      # @response:  
      #   {result: true, is_favourite}
      def unfavourite
        @result = @user.unfavour_document!(@doc, params[:action_time])

        if (@result[:error] rescue false)
          @error = @result[:error]
          @error_code = @result[:error_code]
          return render_error
        end
      end


      ##
      # Mark a doc as read
      # /docs/mark_as_read.json
      # POST
      # @params: 
      #   token, company_id, doc_id, action_time
      # @response:  
      #   {result: true, is_unread}
      def mark_as_read
        @result = @user.read_document!(@doc, params[:action_time])

        if (@result[:error] rescue false)
          @error = @result[:error]
          @error_code = @result[:error_code]
          return render_error
        end
      end

      ##
      # Mark all docs as read and understood  
      # api/docs/mark_all_as_read.json  
      # POST
      # @params: 
      #   token
      # @response:  
      #   {result: true}
      def mark_all_as_read
        @result = @user.read_all_documents!

        if (@result[:error] rescue false)
          @error = @result[:error]
          @error_code = @result[:error_code]
          return render_error
        end
      end

      ##
      # Search Documents
      # /docs.json
      # GET
      # @params: 
      #   search_term
      # @response:  
      #  { 
      #    docs: [ 
      #         { uid, title, doc_file, version, is_unread, is_inactive, is_favourite, category } 
      #    ] 
      #  } {is_private: false}, {is_private: true, private_for_id: current_user.id}
      def index
        @documents, total_count = Document.get_all(@user, @company, {page: nil, per_page: nil, search: params[:search_term], 
          sort_by: [[:created_at, :desc]], filter: "all", category_id: nil, types: "all", order_by_ranking: "true"})
      end

      private

      def document_required
        is_invalid_doc = true

        if params[:doc_id].present?
          @doc = Document.where(id: params[:doc_id]).first
          is_invalid_doc = false if @doc.present?
        end

        if is_invalid_doc
          @error = I18n.t('document.not_found')
          @error_code = ERROR_CODES[:item_not_found]
          render "api/v1/shared/error"
          return false
        else
          if @doc.is_expiried
            @error = I18n.t('document.is_expiried')
            @error_code = ERROR_CODES[:refresh_data]
            render "api/v1/shared/error"
            return false
          elsif (@doc.is_private && @doc.private_for_id != @user.id)
            @error = I18n.t('document.is_private')
            @error_code = ERROR_CODES[:refresh_data]
            render "api/v1/shared/error"
            return false
          elsif @company && !@company.document_ids.include?(@doc.id)
            @error = I18n.t('document.not_belongs_to_company')
            @error_code = ERROR_CODES[:refresh_data]
            render "api/v1/shared/error"
            return false
          end

          return true
        end
      end
    end
  end
end
