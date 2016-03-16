class Permission
  include Mongoid::Document
  include Mongoid::Timestamps

  STANDARD_PERMISSIONS = {
    company_representative_user: {
      name: "Company Representative",
      permissions: [:add_edit_documents, :view_all_user_read_receipt_reports, :view_all_user_read_receipt_reports_under_assignment, 
        :view_edit_company_billing_info_data_usage, :add_edit_company_representative_user, :add_edit_admin_user, :add_edit_approver_user, 
        :add_edit_supervisor_user, :add_edit_standard_user, :add_edit_document_control_admin_user, :add_edit_document_control_standard_user, 
        :can_make_document_restricted, :can_edit_organisation_structure, :view_all_accountability_reports, 
        :view_accountability_reports_under_assignment, :is_supervisor_user, :bulk_assign_documents
      ],
      code: "company_representative_user"
    },
    admin_user: {
      name: "Admin",
      permissions: [:view_all_user_read_receipt_reports, :add_edit_admin_user, :add_edit_approver_user,
        :add_edit_supervisor_user, :add_edit_standard_user
      ],
      code: "admin_user"
    },
    supervisor_user: {
      name: "Supervisor",
      permissions: [:is_supervisor_user, :view_all_user_read_receipt_reports_under_assignment],
      code: "supervisor_user"
    },
    document_control_admin_user: {
      name: "Document Control Admin",
      permissions: [:add_edit_documents, :view_all_user_read_receipt_reports_under_assignment, 
        :add_edit_document_control_admin_user,
        :add_edit_document_control_standard_user, :can_make_document_restricted
      ],
      code: "document_control_admin_user"
    },
    document_control_standard_user: {
      name: "Document Control User",
      permissions: [:add_edit_documents, :can_make_document_restricted],
      code: "document_control_standard_user"
    },
    approver_user: {
      name: "Approver",
      permissions: [:is_approval_user, :view_all_user_read_receipt_reports_under_assignment, :bulk_assign_documents],
      code: "approver_user"
    },
    standard_user: {
      name: "Standard",
      permissions: [],
      code: "standard_user"
    }
  }

  CUSTOM_PERMISSION_CODE = "custom_permission"

  RULES = {
    add_edit_documents: {
      read: [Document],
      create: [Document],
      update: [Document]
    },
    view_all_user_read_receipt_reports: {},
    view_all_user_read_receipt_reports_under_assignment: {},
    view_edit_company_billing_info_data_usage: {},
    add_edit_company_representative_user: {
      read: ["user_type_company_representative_user"],
      create: ["user_type_company_representative_user"],
      update: ["user_type_company_representative_user"]
    },
    add_edit_admin_user: {
      read: ["user_type_admin_user"],
      create: ["user_type_admin_user"],
      update: ["user_type_admin_user"]
    },
    add_edit_approver_user: {
      read: ["user_type_approver_user"],
      create: ["user_type_approver_user"],
      update: ["user_type_approver_user"]
    },
    add_edit_supervisor_user: {
      read: ["user_type_supervisor_user"],
      create: ["user_type_supervisor_user"],
      update: ["user_type_supervisor_user"]
    },
    add_edit_standard_user: {
      read: ["user_type_standard_user"],
      create: ["user_type_standard_user"],
      update: ["user_type_standard_user"]
    },
    add_edit_document_control_admin_user: {
      read: ["user_type_document_control_admin"],
      create: ["user_type_document_control_admin"],
      update: ["user_type_document_control_admin"]
    },
    add_edit_document_control_standard_user: {
      read: ["user_type_document_control_standard_user"],
      create: ["user_type_document_control_standard_user"],
      update: ["user_type_document_control_standard_user"]
    },
    is_approval_user: {},

    is_supervisor_user: {},

    can_make_document_restricted: {

    },
    can_edit_organisation_structure: {},

    view_all_accountability_reports: {},
    view_accountability_reports_under_assignment: {}
  }

  ADD_EDIT_USER_FIELDS = ["add_edit_company_representative_user", "add_edit_admin_user", "add_edit_approver_user", 
      "add_edit_supervisor_user",  "add_edit_standard_user", "add_edit_document_control_admin_user",
      "add_edit_document_control_standard_user" ]

  field :name, type: String
  field :code, type: String

  # Add / Edit Documents  
  field :add_edit_documents, type: Boolean, default: false

  # View All User Read Receipt Reports  
  field :view_all_user_read_receipt_reports, type: Boolean, default: false

  # View User Read Receipt Reports under Assignment 
  field :view_all_user_read_receipt_reports_under_assignment, type: Boolean, default: false

  # View / Edit Company Billing Info / Data Usage 
  field :view_edit_company_billing_info_data_usage, type: Boolean, default: false

  # Add / Edit Company Representative User  
  field :add_edit_company_representative_user, type: Boolean, default: false

  # Add / Edit Admin User 
  field :add_edit_admin_user, type: Boolean, default: false

  # Add / Edit Approver User  
  field :add_edit_approver_user, type: Boolean, default: false

  # Add / Edit Supervisor User
  field :add_edit_supervisor_user, type: Boolean, default: false

  # Add / Edit Standard User  
  field :add_edit_standard_user, type: Boolean, default: false

  # Add / Edit Document Control Admin User  
  field :add_edit_document_control_admin_user, type: Boolean, default: false

  # Add / Edit Document Control Standard User 
  field :add_edit_document_control_standard_user, type: Boolean, default: false

  # View Document Control Reports (DatPB: Not need at current)
  field :view_document_control_reports, type: Boolean, default: false

  # Is Approval User
  field :is_approval_user, type: Boolean, default: false

  field :is_supervisor_user, type: Boolean, default: false

  # Can make document restricted
  field :can_make_document_restricted, type: Boolean, default: false

  #Can edit organisation structure 
  field :can_edit_organisation_structure, type: Boolean, default: false

  #View All Accountability Reports
  field :view_all_accountability_reports, type: Boolean, default: false

  #View Accountability Reports under Assignment
  field :view_accountability_reports_under_assignment, type: Boolean, default: false

  #Add permission "Bulk assign documents": everybody can has - this is for the purpose of approvers
  #can assign other non-restricted documents to the areas that they approve for
  field :bulk_assign_documents, type: Boolean, default: false

  field :is_custom, type: Boolean, default: false

  field :for_user_name, type: String
  field :for_user_id, type: String

  field :user_type, type: String

  belongs_to :company

  validates_presence_of :name, :company
  validates_uniqueness_of :name, scope: :company_id
  validates_uniqueness_of :code, scope: :company_id

  scope :standard, -> {where(is_custom: false)}

  before_save do
    if is_custom
      self.code = "custom_code_#{name.to_s.downcase.gsub(' ', '_')}"
      self.user_type = STANDARD_PERMISSIONS[user_type.try(:to_sym)][:code] rescue STANDARD_PERMISSIONS[:standard_user][:code]
    else
      STANDARD_PERMISSIONS.keys.each do |key|
        stand_perm = STANDARD_PERMISSIONS[key]
        if stand_perm[:name] == name
          self.code = key.to_s
          self.user_type = key.to_s
          break
        end
      end
    end

    if is_approval_user || user_type == STANDARD_PERMISSIONS[:approver_user][:code] ||
      user_type == STANDARD_PERMISSIONS[:company_representative_user][:code]

      self.bulk_assign_documents = true
    end

    true
  end

  after_save do
    if is_approval_user_changed? || is_supervisor_user_changed? ||
      view_all_user_read_receipt_reports_changed? || view_all_user_read_receipt_reports_under_assignment_changed?
      
      UserCompany.where(permission_id: self.id).each do |u_comp|
        u_comp.updated_at = Time.now.utc
        u_comp.save
      end
    end
  end

  def full_name
    if is_custom
      name = self.name
      name_parts = name.split(" #")
      if name_parts.length == 1
        name
      else
        user_id = name_parts[1]
        if (u_name = for_user_name) || (u_name = User.where(:id => user_id).pluck(:name).first)
          "#{name_parts[0]} for #{u_name}"
        else
          name
        end
      end
    else
      self.name
    end
  end

  ##
  # Create standard permissions for new company
  ##
  def self.create_standard_permissions(comp)
    return unless comp

    perms = STANDARD_PERMISSIONS.keys
    if comp.is_standard?
      perms.delete(:approver_user)
    end

    perms.each do |key|
      stand_perm = STANDARD_PERMISSIONS[key]

      perm_hash = { name: stand_perm[:name], code: key.to_s }

      stand_perm[:permissions].each do |perm|
        perm_hash[perm] = true
      end

      comp.permissions.create(perm_hash)
    end
  end

  ##
  # Update batch of permissions
  ##
  def self.update_batch(current_user, comp, perms_arr)
    begin
      perms_obj = []
      changes = {}

      perms_arr.values.each do |perm_hash|
        perm_obj = comp.permissions.find(perm_hash["id"])

        perm_changes = {}
        attrs = {}
        RULES.keys.each do |key|
          attrs[key] = perm_hash[key.to_s]

          if attrs[key].to_s != perm_obj[key].to_s
            perm_changes[key.to_s] = [perm_obj[key].to_s, attrs[key]]
          end
        end

        perms_obj << {
          obj: perm_obj,
          attrs: attrs
        }

        unless perm_changes.blank?
          perm_changes["name"] = perm_obj.full_name
          changes[perm_hash["id"]] = perm_changes
        end
      end

      perms_obj.each do |pm|
        pm[:obj].update(pm[:attrs])
      end

      unless changes.blank?
        comp.create_logs({user_id: current_user.id, action: ActivityLog::ACTIONS[:updated_permission], attrs_changes: {"permissions" => changes}})
      end

      return {success: true}
    rescue Exception => e
      return {success: false, error: e.message}
    end
  end

  def self.custom_perm_name(uid)
    I18n.t("permission.#{CUSTOM_PERMISSION_CODE}").concat(" ##{uid}")
  end
end