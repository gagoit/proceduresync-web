require 'openssl'
class HomeController < ApplicationController
  before_filter :authenticate_user!, only: [:dashboard, :administrator_contact, :staff_with_outstanding_documents]

  before_filter :check_company, except: [:index, :terms_and_conditions, :terms_and_conditions]

  def index
    render layout: "not_signed_in"
  end

  def dashboard
    docs = current_user.docs(current_company, "unread")
    @unread_documents = docs[:docs].limit(3)
  end

  def administrator_contact

  end

  def staff_with_outstanding_documents
    data = UserService.staff_with_outstanding_documents(current_user, current_company, page: params[:page], per_page: params[:per_page])

    render :json => {docs_html: render_to_string(partial: "home/staff_with_outstanding_documents_content", locals: {data: data}, formats: [:html])}
  end

  def support_login
    utctime = time_in_utc
    query = {
      name: current_user.name,
      email: current_user.email,
      timestamp: utctime,
      hash: gen_hash_from_params_hash(utctime)
    }
    redirect_url = CONFIG['freshdesk_domain_name'] + "/login/sso?" + query.to_query

    redirect_to redirect_url
  end

  def gen_hash_from_params_hash(utctime)
    digest  = OpenSSL::Digest::Digest.new('MD5')
    OpenSSL::HMAC.hexdigest(digest, CONFIG['freshdesk_sso_decret'],"#{current_user.name}#{CONFIG['freshdesk_sso_decret']}#{current_user.email}#{utctime}")
  end

  ##
  # Static Files
  ##
  def static_files
    result = {}
    
    StaticFile.all.each do |s_f|
      view_url = assets_url = ""
      view_url, assets_url = s_f.get_box_url
      file_access_token = NewBox::GetFileToken.call(s_f.box_view_id)

      result[s_f.name] = {
        view_url: view_url,
        assets_url: assets_url,
        file_access_token: file_access_token
      }
    end
    
    render :json => result
  end

  private

  def time_in_utc
    Time.now.advance(minutes: -10).getutc.to_i.to_s
  end
end
