class ApproverDocument
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :user
  belongs_to :document

  # approve_all: "Approve to all users in approver area"
  # approve_selected_areas: "approved to the specific areas"
  # not_approve: "Not accountable for approver section(s)."
  field :approve_document_to, type: String

  field :approved_paths, type: Array, default: []
  field :not_approved_paths, type: Array, default: []

  field :params, type: Hash, default: {}

  index({user_id: 1, document_id: 1})
  index({user_id: 1})
  index({document_id: 1})

  validates_presence_of :user_id, :document_id, :approve_document_to
  validates_uniqueness_of :document_id, scope: [:user_id]

  after_save do
    if document && (approve_document_to_changed? || approved_paths_changed?)
      document.create_logs({user_id: user_id, action: ActivityLog::ACTIONS[:approved_document], 
        attrs_changes: params})
    end
  end
end