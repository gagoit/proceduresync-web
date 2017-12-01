##
# Test sites:
##
class TestSite
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :code, type: String
  field :type, type: String # box_view, ..

  field :info, type: Hash, default: {}
  field :url, type: String
  
  validates_presence_of :name, :code, :type
  validates_uniqueness_of :code

  index({code: 1})
  index({code: 1, type: 1})

  before_save do
    self.url = "#{Rails.application.config.action_mailer.asset_host}/#{get_path}?code=#{code}"
  end

  def get_path
    if type == "box_view"
      "test_box_view"
    else
      ""
    end
  end
end