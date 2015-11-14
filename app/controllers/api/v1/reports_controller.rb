module Api
  module V1
    class ReportsController < ApplicationController
      respond_to :json

      before_filter :token_required, :only => [:index, :companies]

      ##
      # Reports: Get companies
      # /reports.json
      # POST
      # @params: 
      #   token
      # @response:  
      #  { 
      #    reports: [ 
      #        {
      #             name: ,
      #             users: [
      #                 { name, unread_number },  
      #                 { name, unread_number }
      #             ]
      #        }, 
      #        {
      #              name: ,
      #              users: []
      #         } 
      #     ] 
      # }"
      def index
        @reports = ReportService.get_report_ws(@user)
      end

      ##
      # Reports: Get companies
      # /reports.json
      # POST
      # @params: 
      #   token
      # @response:  
      #  { 
      #    companies: [ 
      #        {
      #             name: ,
      #             logo_url,
      #             uid
      #        }, 
      #        {
      #              name: ,
      #              logo_url,
      #              uid
      #         } 
      #     ] 
      # }"
      def companies
        @companies = @user.companies.active.order([:name, :asc])
      end

      private

    end
  end
end
