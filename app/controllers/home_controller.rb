require 'openssl'
class HomeController < ApplicationController
  before_filter :authenticate_user!, only: [:dashboard, :administrator_contact]

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
    OpenSSL::HMAC.hexdigest(digest, CONFIG['freshdesk_sso_decret'],"#{current_user.name}#{current_user.email}#{utctime}")
  end

  ##
  # Static Files
  ##
  def static_files
    result = {}
    
    StaticFile.all.each do |s_f|
      view_url = assets_url = ""
      view_url, assets_url = s_f.get_box_url

      result[s_f.name] = {
        view_url: view_url,
        assets_url: assets_url
      }
    end
    
    render :json => result
  end

  private

  def time_in_utc
    Time.now.advance(minutes: -10).getutc.to_i.to_s
  end
end
