class ApplicationController < ActionController::Base
  include ApplicationHelper
  
  rescue_from ActionController::RoutingError, :with => :render_routing_fail
  rescue_from AbstractController::ActionNotFound, :with => :render_not_found
  rescue_from Mongoid::Errors::DocumentNotFound, :with => :render_not_found
  #rescue_from ::BSON::InvalidObjectId, :with => :render_bad_request
  rescue_from CanCan::AccessDenied, :with => :render_access_denied

  layout :layout_by_resource

  before_filter :set_cache_buster

  def set_cache_buster
    response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "Fri, 01 Jan 1990 00:00:00 GMT"
  end

  def token_required
    is_invalid_token = true

    if params[:token].present?
      @user = User.where(token: params[:token]).first
      is_invalid_token = false if @user.present?
    end

    if is_invalid_token
      @error = I18n.t('user.null_or_invalid_token')
      @error_code = ERROR_CODES[:invalid_value]
      render "api/v1/shared/error"
      return false
    else
      unless (@user.active && @user.company_ids.length > 0)
        @error = t("user.disabled")
        @error_code = ERROR_CODES[:user_is_inactive]
        render "api/v1/shared/error"
        return false
      end

      return true
    end
  end

  def company_required
    is_invalid_company = true

    if params[:company_id].present?
      @company = Company.where(id: params[:company_id]).first
      is_invalid_company = false if @company.present?
    end

    if is_invalid_company
      @error = I18n.t('company.null_or_invalid_id')
      @error_code = ERROR_CODES[:invalid_value]
      render "api/v1/shared/error"
      return false
    elsif @user 
      unless @user.is_belongs_to_company(@company)
        @error = I18n.t('company.user_is_not_belongs_to')
        @error_code = ERROR_CODES[:refresh_data]
        render "api/v1/shared/error"
        return false
      end
    end

    return true
  end

  ##
  # get user from token, for checking user like/unlike a post
  ##
  def get_user_from_token
    is_invalid_token = true

    if params[:token].present?
      token_user = User.where(token: params[:token]).first
      is_invalid_token = false if token_user.present?
    end

    if is_invalid_token
      return nil
    else
      return token_user
    end
  end
  
  def is_alive
    render json: {ok: true}
  end

  def signin
    if tablet_device? || mobile_device?
      redirect_to "proceduresync://?email=#{params[:email]}&password=#{params[:password]}"
      return
    end

    if current_user
      sign_out current_user
    end

    #Web admin
    user = User.where(email_downcase: params[:email].to_s.downcase).first

    if user.nil?
      flash[:alert] = t("user.email_not_found")
      redirect_to new_session_path(User, {email: params[:email]})
      return
    end

    unless user.valid_password?(params[:password])
      flash[:alert] = t("user.password_invalid")
      redirect_to new_session_path(User, {email: params[:email]})
      return
    end

    if user.sign_in_count > 0
      sign_in user
      redirect_to after_sign_in_path_for(user)
    else
      redirect_to new_session_path(User, {email: params[:email], password: params[:password]})
    end

    return
  end
  
  def after_sign_in_path_for(user)
    session.delete(:login_next) if session[:login_next]

    if user.admin
      session[:company_id] = Company.first.try(:id)
      '/admin'
    else
      session[:company_id] = user.companies.active.first.try(:id)

      if user.disabled? || session[:company_id].nil?
        flash[:notice] = nil
        flash[:alert] = session[:company_id].nil? ? t("company.is_inactive") : t("user.disabled")

        sign_out user
        main_app.root_url
      elsif !user.has_setup || user.remind_mark_as_read_later
        setup_user_path(user)
      else
        dashboard_path
      end
    end
  end

  # Overwriting the sign_out redirect path method
  def after_sign_out_path_for(resource_or_scope)
    new_user_session_path
  end

  protected

  def render_error
    render "api/v1/shared/error"
    return
  end

  def layout_by_resource
    if devise_controller?
      "not_signed_in"
    else
      "application"
    end
  end

  def render_access_denied
    session[:login_next] = request.path

    opts = {}
    if !current_user || current_user.disabled?
      opts[:message] = t("user.disabled")
      sign_out current_user
      path = main_app.root_url
    else
      path = main_app.dashboard_path
    end

    render_message :access_denied, path, opts
  end

  def render_not_found
    render_message :not_found
  end

  def render_bad_request
    render_message :bad_request
  end

  def render_routing_fail
    render_message :routing_fail
  end

  def render_message(key, path = main_app.root_url, opts = {})
    @msg = opts[:message] || t("error.#{key}")

    code = case key
    when :access_denied then 401
    when :not_found, :routing_fail then 404
    when :bad_request then 400
    end

    respond_to do |format|
      format.html { redirect_to path, {alert: @msg, status: 303} }

      format.json { render json: {
          success: false,
          message: @msg,
          window_reload: true
        } 
      }

      format.js { render "shared/error" }

      format.all { redirect_to path, {alert: @msg, status: 303} }
    end
  end

  def with_format(format, &block)
    old_formats = formats
    self.formats = [format]
    block.call
    self.formats = old_formats
    nil
  end

  def check_permission(target_object)
    # puts "------------check_permission------------"
    # puts target_object.inspect

    if !current_user || current_user.disabled?
      @msg = t("user.disabled")
      error = true
      path = main_app.root_url
    else
      error = !PermissionService.has_permission(params[:action].to_sym, current_user, current_company, target_object)
      @msg = t("error.access_denied")
      path = main_app.dashboard_path
    end
      
    return true if !error
       
    render_message(:access_denied, path, {message: @msg})

    false
  end

  ##
  # check_company for each request
  # if no company is found or (company is inactive and current user is not admin)
  #   => invalid request => logout current user, redirect to root path and display message
  ##
  def check_company
    error = false
    is_admin = (current_user && (current_user.try(:admin) || current_user.try(:super_help_desk_user)))
    
    if !current_company || (!is_admin && !current_company.active)
      @msg = t("company.is_inactive")
      error = true
      sign_out current_user

      path = main_app.root_url

      render_message(:access_denied, path, {message: @msg})
    end

    !error
  end

  TABLET_USER_AGENTS = /ipad|ipad.*mobile|android.*nexus[s]+(7|10)|^.*android.*nexus(?:(?!mobile).)*$|samsung.*tablet|galaxy.*tab|sc-01c|gt-p1000|gt-p1003|gt-p1010|gt-p3105|gt-p6210|gt-p6800|gt-p6810|gt-p7100|gt-p7300|gt-p7310|gt-p7500|gt-p7510|sch-i800|sch-i815|sch-i905|sgh-i957|sgh-i987|sgh-t849|sgh-t859|sgh-t869|sph-p100|gt-p3100|gt-p3108|gt-p3110|gt-p5100|gt-p5110|gt-p6200|gt-p7320|gt-p7511|gt-n8000|gt-p8510|sgh-i497|sph-p500|sgh-t779|sch-i705|sch-i915|gt-n8013|gt-p3113|gt-p5113|gt-p8110|gt-n8010|gt-n8005|gt-n8020|gt-p1013|gt-p6201|gt-p7501|gt-n5100|gt-n5105|gt-n5110|shv-e140k|shv-e140l|shv-e140s|shv-e150s|shv-e230k|shv-e230l|shv-e230s|shw-m180k|shw-m180l|shw-m180s|shw-m180w|shw-m300w|shw-m305w|shw-m380k|shw-m380s|shw-m380w|shw-m430w|shw-m480k|shw-m480s|shw-m480w|shw-m485w|shw-m486w|shw-m500w|gt-i9228|sch-p739|sch-i925|gt-i9200|gt-i9205|gt-p5200|gt-p5210|gt-p5210x|sm-t311|sm-t310|sm-t310x|sm-t210|sm-t210r|sm-t211|sm-p600|sm-p601|sm-p605|sm-p900|sm-p901|sm-t217|sm-t217a|sm-t217s|sm-p6000|sm-t3100|sgh-i467|xe500|sm-t110|gt-p5220|gt-i9200x|gt-n5110x|gt-n5120|sm-p905|sm-t111|sm-t2105|sm-t315|sm-t320|sm-t320x|sm-t321|sm-t520|sm-t525|sm-t530nu|sm-t230nu|sm-t330nu|sm-t900|xe500t1c|sm-p605v|sm-p905v|sm-p600x|sm-p900x|sm-t210x|sm-t230|sm-t230x|sm-t325|gt-p7503|sm-t531|sm-t330|sm-t530|sm-t705c|sm-t535|sm-t331|kindle|silk.*accelerated|android.*(kfot|kftt|kfjwi|kfjwa|kfote|kfsowi|kfthwi|kfthwa|kfapwi|kfapwa|wfjwae)|windows nt [0-9.]+; arm;|hp slate 7|hp elitepad 900|hp-tablet|elitebook.*touch|hp 8|^.*padfone((?!mobile).)*$|transformer|tf101|tf101g|tf300t|tf300tg|tf300tl|tf700t|tf700kl|tf701t|tf810c|me171|me301t|me302c|me371mg|me370t|me372mg|me172v|me173x|me400c|slider sl101|k00f|tx201la|playbook|rim tablet|htc flyer|htc jetstream|htc-p715a|htc evo view 4g|pg41200|xoom|sholest|mz615|mz605|mz505|mz601|mz602|mz603|mz604|mz606|mz607|mz608|mz609|mz615|mz616|mz617|android.*nook|nookcolor|nook browser|bnrv200|bnrv200a|bntv250|bntv250a|bntv400|bntv600|logicpd zoom2|android.*; (a100|a101|a110|a200|a210|a211|a500|a501|a510|a511|a700|a701|w500|w500p|w501|w501p|w510|w511|w700|g100|g100w|b1-a71|b1-710|b1-711|a1-810|a1-830)|w3-810|a3-a10|android.*(at100|at105|at200|at205|at270|at275|at300|at305|at1s5|at500|at570|at700|at830)|toshiba.*folio|l-06c|lg-v900|lg-v500|lg-v909|lg-v500|lg-v510|lg-vk810|android.*(f-01d|f-02f|f-05e|f-10d|m532|q572)|pmp3170b|pmp3270b|pmp3470b|pmp7170b|pmp3370b|pmp3570c|pmp5870c|pmp3670b|pmp5570c|pmp5770d|pmp3970b|pmp3870c|pmp5580c|pmp5880d|pmp5780d|pmp5588c|pmp7280c|pmp7280c3g|pmp7280|pmp7880d|pmp5597d|pmp5597|pmp7100d|per3464|per3274|per3574|per3884|per5274|per5474|pmp5097cpro|pmp5097|pmp7380d|pmp5297c|pmp5297c_quad|ideatab|thinkpad([ ]+)?tablet|lenovo.*(s2109|s2110|s5000|s6000|k3011|a3000|a1000|a2107|a2109|a1107|b6000|b8000|b8080-f)|android.*(tab210|tab211|tab224|tab250|tab260|tab264|tab310|tab360|tab364|tab410|tab411|tab420|tab424|tab450|tab460|tab461|tab464|tab465|tab467|tab468|tab07-100|tab07-101|tab07-150|tab07-151|tab07-152|tab07-200|tab07-201-3g|tab07-210|tab07-211|tab07-212|tab07-214|tab07-220|tab07-400|tab07-485|tab08-150|tab08-200|tab08-201-3g|tab08-201-30|tab09-100|tab09-211|tab09-410|tab10-150|tab10-201|tab10-211|tab10-400|tab10-410|tab13-201|tab274euk|tab275euk|tab374euk|tab462euk|tab474euk|tab9-200)|android.*oyo|life.*(p9212|p9514|p9516|s9512)|lifetab|an10g2|an7bg3|an7fg3|an8g3|an8cg3|an7g3|an9g3|an7dg3|an7dg3st|an7dg3childpad|an10bg3|an10bg3dt|inm8002kp|inm1010fp|inm805nd|intenso tab|m702pro|megafon v9|zte v9|android.*mt7a|e-boda (supreme|impresspeed|izzycomm|essential)|allview.*(viva|alldro|city|speed|all tv|frenzy|quasar|shine|tx1|ax1|ax2)|(101g9|80g9|a101it)|qilive 97r|archos 101g10|archos 101 neon|novo7|novo8|novo10|novo7aurora|novo7basic|novo7paladin|novo9-spark|sony.*tablet|xperia tablet|sony tablet s|so-03e|sgpt12|sgpt13|sgpt114|sgpt121|sgpt122|sgpt123|sgpt111|sgpt112|sgpt113|sgpt131|sgpt132|sgpt133|sgpt211|sgpt212|sgpt213|sgp311|sgp312|sgp321|ebrd1101|ebrd1102|ebrd1201|sgp351|sgp341|sgp511|sgp512|sgp521|sgp541|sgp551|android.*(k8gt|u9gt|u10gt|u16gt|u17gt|u18gt|u19gt|u20gt|u23gt|u30gt)|cube u8gt|mid1042|mid1045|mid1125|mid1126|mid7012|mid7014|mid7015|mid7034|mid7035|mid7036|mid7042|mid7048|mid7127|mid8042|mid8048|mid8127|mid9042|mid9740|mid9742|mid7022|mid7010|m9701|m9000|m9100|m806|m1052|m806|t703|mid701|mid713|mid710|mid727|mid760|mid830|mid728|mid933|mid125|mid810|mid732|mid120|mid930|mid800|mid731|mid900|mid100|mid820|mid735|mid980|mid130|mid833|mid737|mid960|mid135|mid860|mid736|mid140|mid930|mid835|mid733|android.*(mid|mid-560|mtv-t1200|mtv-pnd531|mtv-p1101|mtv-pnd530)|android.*(rk2818|rk2808a|rk2918|rk3066)|rk2738|rk2808a|iq310|fly vision|bq.*(elcano|curie|edison|maxwell|kepler|pascal|tesla|hypatia|platon|newton|livingstone|cervantes|avant)|maxwell.*lite|maxwell.*plus|mediapad|mediapad 7 youth|ideos s7|s7-201c|s7-202u|s7-101|s7-103|s7-104|s7-105|s7-106|s7-201|s7-slim|n-06d|n-08d|pantech.*p4100|broncho.*(n701|n708|n802|a710)|touchpad.*[78910]|touchtab|z1000|z99 2g|z99|z930|z999|z990|z909|z919|z900|tb07sta|tb10sta|tb07fta|tb10fta|android.*nabi|kobo touch|k080|vox build|arc build|dslide.*(700|701r|702|703r|704|802|970|971|972|973|974|1010|1012)|navipad|tb-772a|tm-7045|tm-7055|tm-9750|tm-7016|tm-7024|tm-7026|tm-7041|tm-7043|tm-7047|tm-8041|tm-9741|tm-9747|tm-9748|tm-9751|tm-7022|tm-7021|tm-7020|tm-7011|tm-7010|tm-7023|tm-7025|tm-7037w|tm-7038w|tm-7027w|tm-9720|tm-9725|tm-9737w|tm-1020|tm-9738w|tm-9740|tm-9743w|tb-807a|tb-771a|tb-727a|tb-725a|tb-719a|tb-823a|tb-805a|tb-723a|tb-715a|tb-707a|tb-705a|tb-709a|tb-711a|tb-890hd|tb-880hd|tb-790hd|tb-780hd|tb-770hd|tb-721hd|tb-710hd|tb-434hd|tb-860hd|tb-840hd|tb-760hd|tb-750hd|tb-740hd|tb-730hd|tb-722hd|tb-720hd|tb-700hd|tb-500hd|tb-470hd|tb-431hd|tb-430hd|tb-506|tb-504|tb-446|tb-436|tb-416|tb-146se|tb-126se|playstation.*(portable|vita)|st10416-1|vt10416-1|st70408-1|st702xx-1|st702xx-2|st80208|st97216|st70104-2|vt10416-2|st10216-2a|(ptbl10ceu|ptbl10c|ptbl72bc|ptbl72bceu|ptbl7ceu|ptbl7c|ptbl92bc|ptbl92bceu|ptbl9ceu|ptbl9cuk|ptbl9c)|android.* (e3a|t3x|t5c|t5b|t3e|t3c|t3b|t1j|t1f|t2a|t1h|t1i|e1c|t1-e|t5-a|t4|e1-b|t2ci|t1-b|t1-d|o1-a|e1-a|t1-a|t3a|t4i) |genius tab g3|genius tab s2|genius tab q3|genius tab g4|genius tab q4|genius tab g-ii|genius tab gii|genius tab giii|genius tab s1|android.*g1|funbook|micromax.*(p250|p560|p360|p362|p600|p300|p350|p500|p275)|android.*(a39|a37|a34|st8|st10|st7|smart tab3|smart tab2)|fine7 genius|fine7 shine|fine7 air|fine8 style|fine9 more|fine10 joy|fine11 wide|(pem63|plt1023g|plt1041|plt1044|plt1044g|plt1091|plt4311|plt4311pl|plt4315|plt7030|plt7033|plt7033d|plt7035|plt7035d|plt7044k|plt7045k|plt7045kb|plt7071kg|plt7072|plt7223g|plt7225g|plt7777g|plt7810k|plt7849g|plt7851g|plt7852g|plt8015|plt8031|plt8034|plt8036|plt8080k|plt8082|plt8088|plt8223g|plt8234g|plt8235g|plt8816k|plt9011|plt9045k|plt9233g|plt9735|plt9760g|plt9770g)|bq1078|bc1003|bc1077|rk9702|bc9730|bc9001|it9001|bc7008|bc7010|bc708|bc728|bc7012|bc7030|bc7027|bc7026|tpc7102|tpc7103|tpc7105|tpc7106|tpc7107|tpc7201|tpc7203|tpc7205|tpc7210|tpc7708|tpc7709|tpc7712|tpc7110|tpc8101|tpc8103|tpc8105|tpc8106|tpc8203|tpc8205|tpc8503|tpc9106|tpc9701|tpc97101|tpc97103|tpc97105|tpc97106|tpc97111|tpc97113|tpc97203|tpc97603|tpc97809|tpc97205|tpc10101|tpc10103|tpc10106|tpc10111|tpc10203|tpc10205|tpc10503|tx-a1301|tx-m9002|q702|kf026|tab-p506|tab-navi-7-3g-m|tab-p517|tab-p-527|tab-p701|tab-p703|tab-p721|tab-p731n|tab-p741|tab-p825|tab-p905|tab-p925|tab-pr945|tab-pl1015|tab-p1025|tab-pi1045|tab-p1325|tab-protab[0-9]+|tab-protab25|tab-protab26|tab-protab27|tab-protab26xl|tab-protab2-ips9|tab-protab30-ips9|tab-protab25xxl|tab-protab26-ips10|tab-protab30-ips10|ov-(steelcore|newbase|basecore|baseone|exellen|quattor|edutab|solution|action|basictab|teddytab|magictab|stream|tb-08|tb-09)|hcl.*tablet|connect-3g-2.0|connect-2g-2.0|me tablet u1|me tablet u2|me tablet g1|me tablet x1|me tablet y2|me tablet sync|dps dream 9|dps dual 7|v97 hd|i75 3g|visture v4( hd)?|visture v5( hd)?|visture v10|ctp(-)?810|ctp(-)?818|ctp(-)?828|ctp(-)?838|ctp(-)?888|ctp(-)?978|ctp(-)?980|ctp(-)?987|ctp(-)?988|ctp(-)?989|mt8125|mt8389|mt8135|mt8377|concorde([ ]+)?tab|concorde readman|goclever tab|a7goclever|m1042|m7841|m742|r1042bk|r1041|tab a975|tab a7842|tab a741|tab a741l|tab m723g|tab m721|tab a1021|tab i921|tab r721|tab i720|tab t76|tab r70|tab r76.2|tab r106|tab r83.2|tab m813g|tab i721|gcta722|tab i70|tab i71|tab s73|tab r73|tab r74|tab r93|tab r75|tab r76.1|tab a73|tab a93|tab a93.2|tab t72|tab r83|tab r974|tab r973|tab a101|tab a103|tab a104|tab a104.2|r105bk|m713g|a972bk|tab a971|tab r974.2|tab r104|tab r83.3|tab a1042|freetab 9000|freetab 7.4|freetab 7004|freetab 7800|freetab 2096|freetab 7.5|freetab 1014|freetab 1001 |freetab 8001|freetab 9706|freetab 9702|freetab 7003|freetab 7002|freetab 1002|freetab 7801|freetab 1331|freetab 1004|freetab 8002|freetab 8014|freetab 9704|freetab 1003|(argus[ _]?s|diamond[ _]?79hd|emerald[ _]?78e|luna[ _]?70c|onyx[ _]?s|onyx[ _]?z|orin[ _]?hd|orin[ _]?s|otis[ _]?s|speedstar[ _]?s|magnet[ _]?m9|primus[ _]?94[ _]?3g|primus[ _]?94hd|primus[ _]?qs|android.*q8|sirius[ _]?evo[ _]?qs|sirius[ _]?qs|spirit[ _]?s)|v07ot2|tm105a|s10ot1|tr10cs1|ezee[_']?(tab|go)[0-9]+|tablc7|looney tunes tab|smarttab([ ]+)?[0-9]+|smarttabii10|smart[ ']?tab[ ]+?[0-9]+|family[ ']?tab2|rm-790|rm-997|rmd-878g|rmd-974r|rmt-705a|rmt-701|rme-601|rmt-501|rmt-711|i-mobile i-note|tolino tab [0-9.]+|tolino shine|c-22q|t7-qc|t-17b|t-17p|android.* a78 |android.* (skypad|phoenix|cyclops)|tecno p9|android.*(f3000|a3300|jxd5000|jxd3000|jxd2000|jxd300b|jxd300|s5800|s7800|s602b|s5110b|s7300|s5300|s602|s603|s5100|s5110|s601|s7100a|p3000f|p3000s|p101|p200s|p1000m|p200m|p9100|p1000s|s6600b|s908|p1000|p300|s18|s6600|s9100)|tablet (spirit 7|essentia|galatea|fusion|onix 7|landa|titan|scooby|deox|stella|themis|argon|unique 7|sygnus|hexen|finity 7|cream|cream x2|jade|neon 7|neron 7|kandy|scape|saphyr 7|rebel|biox|rebel|rebel 8gb|myst|draco 7|myst|tab7-004|myst|tadeo jones|tablet boing|arrow|draco dual cam|aurix|mint|amity|revolution|finity 9|neon 9|t9w|amity 4gb dual cam|stone 4gb|stone 8gb|andromeda|silken|x2|andromeda ii|halley|flame|saphyr 9,7|touch 8|planet|triton|unique 10|hexen 10|memphis 4gb|memphis 8gb|onix 10)|fx2 pad7|fx2 pad10|kidspad 701|pad[ ]?712|pad[ ]?714|pad[ ]?716|pad[ ]?717|pad[ ]?718|pad[ ]?720|pad[ ]?721|pad[ ]?722|pad[ ]?790|pad[ ]?792|pad[ ]?900|pad[ ]?9715d|pad[ ]?9716dr|pad[ ]?9718dr|pad[ ]?9719qr|pad[ ]?9720qr|telepad1030|telepad1032|telepad730|telepad731|telepad732|telepad735q|telepad830|telepad9730|telepad795|megapad 1331|megapad 1851|megapad 2151|viewpad 10pi|viewpad 10e|viewpad 10s|viewpad e72|viewpad7|viewpad e100|viewpad 7e|viewsonic vb733|vb100a|loox|xeno10|odys space|captiva pad|nettab|nt-3702|nt-3702s|nt-3702s|nt-3603p|nt-3603p|nt-0704s|nt-0704s|nt-3805c|nt-3805c|nt-0806c|nt-0806c|nt-0909t|nt-0909t|nt-0907s|nt-0907s|nt-0902s|nt-0902s|hudl ht7s3|t-hub2|android.*97d|tablet(?!.*pc)|bntv250a|mid-wcdma|logicpd zoom2|a7eb|catnova8|a1_07|ct704|ct1002|m721|rk30sdk|evotab|m758a|et904|alumium10|smartfren tab|endeavour 1010|tablet-pc-4/.freeze
  PHONE_USER_AGENTS = /mobile|webos|android/

  def tablet_device?
    user_agent = request.user_agent.to_s.downcase

    !!(user_agent =~ TABLET_USER_AGENTS)
  end

  def mobile_device?
    user_agent = request.user_agent.to_s.downcase
    is_device = (user_agent =~ PHONE_USER_AGENTS)

    !tablet_device? && is_device
  end

  helper_method :mobile_device?, :tablet_device?
end
