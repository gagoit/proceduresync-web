class VisitorsController < ApplicationController
  
  def box_view
    ts = TestSite.where(code: params[:code]).first
    unless ts && ts.type == "box_view" && ts.info[:version_id]
      raise Mongoid::Errors::DocumentNotFound.new(TestSite, params[:code])
    end

    begin
      @version = Version.find(ts.info[:version_id])
      @document = @version.document
    rescue Exception => e
      raise Mongoid::Errors::DocumentNotFound.new(Version, ts.info[:version_id])
    end

    if @version.box_view_id
      @view_url, @assets_url = @version.get_box_url
      @file_access_token = @version.in_new_box ? NewBox::GetFileToken.call(@version.box_view_id) : nil
    end

    render layout: "not_signed_in"
  end
end
