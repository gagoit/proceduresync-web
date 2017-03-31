require 'httparty'

class NotificationService < BaseService

  PLATFORMS = {
    ios: 'ios',
    android: 'android'
  }

  ACTION_TYPES = {
    syn_docs: 1,
    delete_doc: 3,
    company_changed: 4,
    doc_has_changed_privacy: 5,
    user_is_inactive: 6,
    document_has_changed_status: 7,
    users_has_changed_company_path: 8,
    user_has_changed_info: 9,
    user_has_been_changed_report_permission: 10
  }

  def self.pusher
    @@pusher ||= HashWithIndifferentAccess.new YAML.load(File.read(Rails.root.join('config/pusher.yml')))[Rails.env]
  end

  # Create user tags for device in Pusher
  # ==== Parameters
  # * <b>user</b> - User object
  #
  # ==== Returns
  # user's tags that is used in pusher when register devices
  ##
  def self.user_tags(user)
    "Proceduresync_#{user.id}"
  end

  #   POST /devices.json
  #
  # ==== Parameters
  # * <b>device</b> - Device token.
  # * <b>enabled</b> - <em>Optional</em>. If '0', device won't be sent push notifications.
  # * <b>tags</b> - <em>Optional</em>. A comma separated list of tags this device wants to receive notifications from.
  #
  # ==== Returns
  ##
  # Register device to pusher Server
  # we can have more than one apps
  ##
  def self.register_device(user, device_token, access_token, enabled = true)
    uri = self.pusher[:server]

    if access_token.nil?
      Airbrake.notify("[Proceduresync] Invalid pusher access_token for device #{device_token} of user #{user.id}")
      return
    end

    query = {access_token: access_token, device: device_token, tags: user_tags(user), enabled: enabled}
    begin
      # response = HTTParty.post('/devices.json', :query => query, :base_uri => uri) 
    rescue Exception => ex
      if Rails.env.production?
        Airbrake.notify(ex)
      else
        logger.error ex
      end
    end
  end

  #   POST /devices/update_tags_in_device.json
  #
  # ==== Parameters
  # * <b>device</b> - Device token.
  # * <b>enabled</b> - <em>Optional</em>. If '0', device won't be sent push notifications.
  # * <b>tags</b> - <em>Optional</em>. A comma separated list of tags this device wants to receive notifications from.
  #
  # ==== Returns
  ##
  # Add/remove tags from device
  ##
  def self.update_tags_in_device(user, device_token, access_token, enabled = true)
    uri = self.pusher[:server]

    if access_token.nil?
      Airbrake.notify("[Proceduresync] Invalid pusher access_token for device #{device_token} of user #{user.id}")
      return
    end

    query = {access_token: access_token, device: device_token, tags: user_tags(user), enabled: enabled}
    begin
      # response = HTTParty.post('/devices/update_tags_in_device.json', :query => query, :base_uri => uri) 
    rescue Exception => ex
      if Rails.env.production?
        Airbrake.notify(ex)
      else
        logger.error ex
      end
    end
  end

  ##
  # Sent notification to pusher Server
  # we can have more than one app
  ##
  def self.sent_notification(query, access_token)
    uri = self.pusher[:server]

    if access_token.nil?
      Airbrake.notify("[Proceduresync] Invalid pusher access_token")
      return
    end

    query[:access_token] = access_token
    begin
      new_query = query.dup

      if query[:payload]
        if query[:payload].has_key?(:tags) && query[:tags].blank?
          query[:tags] = query[:payload][:tags]
        end

        query[:type] = query[:payload][:type]
      end

      noti = PushNotification.create(query)

      new_query[:content_available] = 1
      new_query[:app_code] = "proceduresync"
      if new_query[:alert].blank?
        new_query.delete(:alert)
        new_query[:badge] = -1
        new_query[:sound] = nil
        new_query[:visible] = false
      end

      new_query[:payload] = {noti_id: noti.id.to_s}

      # response = HTTParty.post('/notifications.json', :query => new_query, :base_uri => uri)
    rescue Exception => ex
      if Rails.env.production?
        Airbrake.notify(ex)
      else
        logger.error ex
      end
    end
  end

  ##
  # Prepare notification for user
  # Collect all devices, prepare the query for each app and send notification
  ##
  def self.prepare_notification(users, alert, payload = {})
    apps_hash = {}

    users.each do |user|
      
      devices = user.devices.enabled.pluck(:token, :app_access_token)

      devices.each do |e|
        # e = [:token, :app_access_token]
        unless apps_hash[e[1]]
          apps_hash[e[1]] = []
        end

        apps_hash[e[1]] << e[0] unless e[0].blank?
      end
    end

    query = { devices: [], instant: true, alert: alert, payload: payload, sound: 'crowd_swell.caf' }

    # send to devices of each app
    apps_hash.keys.each do |app_access_token|
      query[:devices] = apps_hash[app_access_token]

      next if query[:devices].blank?
      
      sent_notification(query, app_access_token)
    end
  end

  ##
  # Prepare notification for user
  # Collect all tags, prepare the query for each app and send notification
  ##
  def self.prepare_notification_using_tags(users, alert, payload = {})
    apps_hash = {}

    users.each do |user|

      apps = user.devices.pluck(:app_access_token).uniq

      current_user_tags = user_tags(user)

      apps.each do |app_access_token|
        next if app_access_token.blank?
        
        unless apps_hash[app_access_token]
          apps_hash[app_access_token] = []
        end

        apps_hash[app_access_token] << current_user_tags
      end
    end

    query = { devices: [], instant: true, alert: alert, payload: payload, sound: 'crowd_swell.caf' }

    # send to devices of each app
    apps_hash.keys.each do |app_access_token|
      query[:tags] = apps_hash[app_access_token].uniq.join(",")

      next if query[:tags].blank?
      
      sent_notification(query, app_access_token)
    end
  end

  ##
  # Notification in case the WS tell the app sync docs in background for user 
  # when the meta data of document has been updated
  ##
  def self.documents_have_changed_meta_data(user_ids, doc_ids)
    alert = ""

    payload = {action_type: ACTION_TYPES[:syn_docs], type: "documents_have_changed_meta_data",
        document_ids: doc_ids.map { |e| e.to_s }}

    users = User.where(:id.in => user_ids)

    prepare_notification_using_tags(users, alert, payload)
  end

  ##
  # Notification when users have new docs
  ##
  def self.add_accountable(user_ids, doc_ids)
    alert = I18n.t("user.has_new_doc")

    payload = {action_type: ACTION_TYPES[:syn_docs], type: "add_accountable",
        document_ids: doc_ids.map { |e| e.to_s }}

    users = User.where(:id.in => user_ids)

    prepare_notification_using_tags(users, alert, payload)
  end

  ##
  # Notification when users have been removed docs
  ##
  def self.remove_accountable(user_ids, doc_ids)
    alert = ""

    payload = {action_type: ACTION_TYPES[:delete_doc], type: "remove_accountable",
        document_ids: doc_ids.map { |e| e.to_s }}

    users = User.where(:id.in => user_ids)

    prepare_notification_using_tags(users, alert, payload)
  end

	##
	# Notification when a doc is created
	##
	def self.document_is_created(doc, user_ids = nil)
    doc.reload

    return unless doc.active

    unless doc.effective
      NotificationService.delay(run_at: (doc.effective_time.try(:utc) || Time.now.utc)).document_is_created(doc, user_ids)
      return
    end

    alert = I18n.t("user.has_new_doc")

    payload = {action_type: ACTION_TYPES[:syn_docs], type: "document_is_created"}

    user_ids ||= doc.available_for_user_ids

    users = User.where(:id.in => user_ids)

    prepare_notification_using_tags(users, alert, payload)
  end

  ##
  # Notification when a doc is invalid/expiry
  ##
  def self.document_is_invalid(doc)
    alert = ""

    payload = {action_type: ACTION_TYPES[:delete_doc], 
      document_ids: [doc.id.to_s], type: "document_is_invalid"}

    if company = doc.company
      users = company.users

      prepare_notification_using_tags(users, alert, payload)
    end
  end

  ##
  # Notification when a doc is invalid/expiry
  ##
  def self.documents_are_invalid(docs)
    alert = ""

    payload = {action_type: ACTION_TYPES[:delete_doc], 
      document_ids: docs.pluck(:id).map { |e| e.to_s }, type: "documents_are_invalid"}

    user_ids = []

    docs.each do |doc|
      if company = doc.company
        user_ids.concat(company.user_ids)
      end
    end

    user_ids.uniq!
    users = User.where(:id.in => user_ids)
    
    prepare_notification_using_tags(users, alert, payload)
  end

  ##
  # Notification when a document_has_changed_privacy
  ##
  def self.document_has_changed_privacy(doc)
    alert = ""

    payload = {action_type: ACTION_TYPES[:doc_has_changed_privacy], 
      document_ids: [doc.id.to_s], type: "document_has_changed_privacy"}

    if company = doc.company
      users = company.users

      prepare_notification_using_tags(users, alert, payload)
    end
  end

  ##
  # Notification when a document_has_changed_status : read / unread / favourite / unfavourite
  ##
  def self.document_has_changed_status(user, doc_ids)
    alert = ""

    payload = {action_type: ACTION_TYPES[:document_has_changed_status], 
      document_ids: doc_ids.map { |e| e.to_s }, type: "document_has_changed_status"}

    prepare_notification_using_tags([user], alert, payload)
  end

  ##
  # Notification when user mark all as read
  ##
  def self.mark_all_as_read(user)
    alert = ""

    payload = {action_type: ACTION_TYPES[:syn_docs], type: "mark_all_as_read"}

    prepare_notification_using_tags([user], alert, payload)
  end

  ##
  # Notification when a company has been changed
  ##
  def self.company_has_been_changed(company)
    alert = ""

    payload = {action_type: ACTION_TYPES[:company_changed], type: "company_has_been_changed"}

    users = company.users
    
    prepare_notification_using_tags(users, alert, payload)
  end

  ##
  # Notification when companies has been removed/added from users
  # type = :added || :removed
  ##
  def self.users_companies_have_been_changed(company_ids, user_ids, type = :added)
    return if company_ids.blank? || user_ids.blank?
    alert = ""

    payload = {action_type: ACTION_TYPES[:company_changed], type: "users_companies_have_been_changed"}

    users = User.where(:id.in => user_ids)

    prepare_notification_using_tags(users, alert, payload)
  end

  ##
  # Notification when user is inactive
  ##
  def self.user_is_inactive(user)
    alert = I18n.t("user.disabled")

    payload = {action_type: ACTION_TYPES[:user_is_inactive], type: "user_is_inactive"}

    prepare_notification_using_tags([user], alert, payload)
  end

  ##
  # Notification when user remove a device
  # Question: Are we able to do something like this without change to the App: When a user views their account on the web portal, 
  #   they can see a list of devices that they have ever been logged into. There could perhaps be a toggle beside each device 
  #   that can be set to “Remote wipe on next sync”.  When a device syncs it can check to see if it is marked for remote wipe 
  #   and if it is it can do the same as if a user is made “inactive” – wipe all app data on the device.  
  #   Once the remote wipe is completed, the device can be removed from the users list and a log stored about the remote wipe.
  ##
  def self.remote_wipe_device(user, device, app_access_token)
    alert = I18n.t("user.devices.remote_wipe.success")

    payload = {action_type: ACTION_TYPES[:user_is_inactive], tags: user_tags(user), type: "remote_wipe_device"}

    query = { devices: [device], instant: true, alert: alert, payload: payload, sound: 'crowd_swell.caf' }

    sent_notification(query, app_access_token)
  end

  ##
  # Sent a test notification to a device
  ##
  def self.sent_test_notification(user, device, app_access_token)
    alert = I18n.t("user.devices.sent_notification.message")

    payload = {action_type: -1, tags: user_tags(user), type: "sent_test_notification"}

    query = { devices: [device], instant: true, alert: alert, payload: payload, sound: 'crowd_swell.caf' }

    sent_notification(query, app_access_token)
  end
  
  ##
  # Notification when user has been change the company path
  ##
  def self.users_has_changed_company_path(users)
    alert = I18n.t("user.has_changed_company_path")

    payload = {action_type: ACTION_TYPES[:users_has_changed_company_path], type: "users_has_changed_company_path"}

    prepare_notification_using_tags(users, alert, payload)
  end

  ##
  # When user's info has been changed
  ##
  def self.user_has_changed_info(user)
    alert = ""

    payload = {action_type: ACTION_TYPES[:user_has_changed_info], type: "user_has_changed_info"}

    prepare_notification_using_tags([user], alert, payload)
  end

  ##
  # When user's info has been changed
  ##
  def self.user_has_been_changed_report_permission(user)
    alert = ""

    payload = {action_type: ACTION_TYPES[:user_has_been_changed_report_permission], type: "user_has_been_changed_report_permission"}

    prepare_notification_using_tags([user], alert, payload)
  end
end