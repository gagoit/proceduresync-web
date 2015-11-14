class UserMailer < ActionMailer::Base

  ##
  # Get email to for each ENV
  # For testing, development: ENV = :test => email will go to test email
  # For live server, ENV = :live => email will go to real email
  ##
  def email_to(email)
    env = :live

    if env == :live
      email
    else
      email_test = 'vuongtieulong02@gmail.com'
    end
  end

  ##
  # Email is sent when user is created
  ##
  def confirmation(user, password)
  	user.reload
  	@user = user
    @password = password

  	to = [@user.email]
    to << @user.home_email unless @user.home_email.blank?

    mail :to => email_to(to), :subject => "[Proceduresync] Confirmation"
  end

  ##
  # Email is sent when user request forgot password
  ##
  def forgot_password(user, password)
    user.reload
    @user = user
    @password = password

    to = [@user.email]
    to << @user.home_email unless @user.home_email.blank?

    mail :to => email_to(to), :subject => "Reset your Proceduresync password"
  end

  def report(user, reports)
    user.reload
    @user = user
    @reports = reports

    to = [@user.email]
    to << @user.home_email unless @user.home_email.blank?

    reports.each do |e|
      attachments[e[:name]] = e[:file]
    end

    mail :to => email_to(to), :subject => "Reports"
  end

  ##
  #
  ##
  def document_to_approve(user_id, comp, doc)
    @user = User.find(user_id)
    @comp = comp.reload
    @doc = doc.reload

    to = [@user.email]
    #to << @user.home_email unless @user.home_email.blank?

    mail :to => email_to(to), :subject => "[Proceduresync] A Document is to be approved"
  end

  ##
  # Daily Approval email
  ##
  def documents_to_approve(user_id, comp, doc_ids)
    @user = User.find(user_id)
    @comp = comp.reload
    @docs_title = Document.where(:id.in => doc_ids).pluck(:title)

    return if @docs_title.length == 0

    to = [@user.email]

    mail :to => email_to(to), :subject => "[Proceduresync] Documents are to be approved"
  end

  ##
  # Alert when missing static file
  ##
  def alert_missing_static_file(file_name)
    @file_name = file_name

    mail :to => "vuongtieulong02@gmail.com", :subject => "[Proceduresync] Missing static file: #{file_name}"
  end
end
