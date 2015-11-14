class Category
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String

  belongs_to :company
  has_many :documents, order: [:created_at, :desc]

  validates_presence_of :name, :company
  validates_uniqueness_of :name, scope: :company_id

  after_save do
    if name_changed?
      self.documents.update_all(category_name: name)
      self.documents.each do |doc|
        doc.has_changed!({update_category: true}) if doc
      end
    end
  end

  ##
  # Calculate number of unread document that a user unread
  ##
  def unread_number(user)
    active_doc_ids = documents.active.map(&:id)
    (active_doc_ids - user.read_document_ids).length
  end
end