class UserDevice
  include Mongoid::Document
  include Mongoid::Timestamps::Created

  PLATFORMS = {
    ios: 'ios',
    android: 'android'
  }

  belongs_to :user, inverse_of: :devices

  field :token, :type => String
  field :platform, :type => String

  field :app_access_token, :type => String

  field :enabled, type: Boolean, default: true
  # Not need

  # When user remove this device, deleted will be true, and will be removed from database when app confirm
  field :deleted, type: Boolean, default: false

  field :device_name, type: String
  field :os_version, type: String

  validates_presence_of :token, :user_id, :app_access_token
  validates_uniqueness_of :token, scope: [:user_id, :app_access_token]

  #validates :platform, :inclusion => { :in => PLATFORMS.values, allow_blank: true}

  scope :ios, -> {where(platform: PLATFORMS[:ios])}
  scope :android, -> {where(platform: PLATFORMS[:android])}

  scope :enabled, -> {any_of({enabled: true}, {enabled: nil})}
  scope :disabled, -> {where(enabled: false)}

  scope :available, -> {where(deleted: false)}

  index({token: 1})
  index({enabled: 1})

  index({enabled: 1, platform: 1})

  index({enabled: 1, app_access_token: 1})

  after_save do
    if token_changed? && token
      NotificationService.delay(queue: "notification_and_convert_doc").register_device(user, token, app_access_token)

      UserDevice.delay.disable_invalid_devices(self)
    end    
  end

  ##
  # Incase when two users are using same device
  # user1, use this device first, register this device with server
  # user1 logout (reinstall app), and user2 login => register this device with server
  # server will delete this device in user1
  ##
  def self.disable_invalid_devices(user_dev)
    user_devs = UserDevice.where(token: user_dev.token)

    user_devs.each do |u_d|
      next if u_d.id == user_dev.id

      u = u_d.user
      if u && u.try(:push_token) == u_d.token
        u.push_token = nil
        u.platform = nil
        u.app_access_token = nil
        u.save
      end

      u_d.destroy
    end
  end

  def destroy
    NotificationService.delay(queue: "notification_and_convert_doc").register_device(user, token, app_access_token, false)

    super
  end
end