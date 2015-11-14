module Api
  module V1
    class CategoriesController < ApplicationController
      respond_to :json

      before_filter :token_required, :only => [:index, :docs]

      ##
      # Categories
      # /categories.json
      # POST
      # @params: 
      #   token
      # @response:  
      #   { 
      #     categories: [ 
      #        {  name, unread_number  } 
      #     ] 
      #   }
      def index
        @categories = Category.all.order([:name, :asc])
      end

      ##
      # Get docs for a  Category
      # /category/docs.json
      # GET
      # @params: 
      #   token, category_id
      # @response:  
      #   { 
      #     docs: [ { uid, title, doc_file, version, is_unread } ], 
      #     unread_number 
      #   }
      def docs
        @category = Category.where(:id => params[:category_id]).first

        unless @category
          @error = t("category.not_found")
          @error_code = ERROR_CODES[:item_not_found]
          return render_error
        end
      end

      private

    end
  end
end
