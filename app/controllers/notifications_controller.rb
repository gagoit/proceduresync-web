class NotificationsController < ApplicationController
  before_filter :authenticate_user!

  before_filter :check_company

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 20
    @notifications = current_user.notifications.where(company_id: current_company.id).page(page).per(per_page)
  end
end
