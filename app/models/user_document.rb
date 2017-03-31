class UserDocument
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :user
  belongs_to :document

  field :is_accountable, type: Boolean, default: true
  field :is_favourited, type: Boolean, default: false
  field :is_read, type: Boolean, default: false

  # This is template model, each company will have a sparate collection based on this model and named #{company_id}_user_documents
  # When you add new index here, you must be add this index to all company's collections:
  #   - Need to add seed to update old collections
  #   - Need to add new index to create_indexes_for_dynamic_collections method in Company model

  INDEXES = [
    {user_id: 1, is_accountable: 1, updated_at: 1},
    {user_id: 1, is_favourited: 1},
    {user_id: 1, is_accountable: 1, updated_at: 1, is_favourited: 1},
    {user_id: 1, document_id: 1},
    {document_id: 1, is_accountable: 1}
  ]

  INDEXES.each do |ind|
    index(ind)
  end

  scope :accountable, -> {where(is_accountable: true)}
  scope :favourited, -> {where(is_favourited: true)}
  scope :read, -> {where(is_read: true)}

  scope :available_for_sync, -> {any_of({is_accountable: true}, {is_favourited: true})}
  scope :not_available_for_sync, -> {where(is_accountable: false, is_favourited: false)}

  validates_presence_of :user_id, :document_id
  validates_uniqueness_of :document_id, scope: [:user_id]
end