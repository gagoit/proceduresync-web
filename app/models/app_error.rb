class AppError
  include Mongoid::Document
  include Mongoid::Timestamps

  STATUSES = {
    new: "new",
    fixed: "fixed"
  }

  field :type, type: String
  field :message, type: String

  field :status, type: String
  field :note, type: String

  belongs_to :company

  validates_presence_of :type, :message
end