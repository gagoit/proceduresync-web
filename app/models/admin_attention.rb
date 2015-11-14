class AdminAttention
  include Mongoid::Document
  include Mongoid::Timestamps

  field :all_path_ids, type: String
  field :lastest_type, type: String

  belongs_to :company

  validates_presence_of :company_id, :all_path_ids, :lastest_type
end