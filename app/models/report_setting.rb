class ReportSetting
  include Mongoid::Document
  include Mongoid::Timestamps

  FREQUENCIES = [:daily, :weekly, :fortnightly, :monthly]

  DOC_STATUSES = [:all, :read, :unread]

  SELECT_USERS_TEXT = "select_users"

  field :frequency, type: String, default: "weekly"
  
  #Areas
  field :areas, type: String, default: SELECT_USERS_TEXT

  #This has All, and all the other parts of the organisation (which is searchable)
  field :users, type: Array, default: ["all"]

  #"All", "Read", "Unread"
  field :doc_status, type: String, default: "all"

  #These are the list of all Categories that have been created for this company.
  field :categories, type: Array, default: ["all"]

  field :is_default, type: Boolean, default: true

  field :automatic_email, type: Boolean, default: false

  field :last_run_date, type: Date
  
  belongs_to :user
  belongs_to :company

  validates_presence_of :user, :company_id, :frequency, :users, :doc_status, :categories

  validates_uniqueness_of :user_id, scope: :company_id

  index({user_id: 1, company_id: 1})

  scope :auto_email, -> {where(automatic_email: true)}

  before_save do 
    if areas != SELECT_USERS_TEXT
      self.users = ["all"]
    end
  end
  
  FREQUENCIES.each do |freq|
    instance_eval <<-RUBY_EVAL
      scope freq, -> {where(frequency: freq.to_s)}
    RUBY_EVAL
  end

end