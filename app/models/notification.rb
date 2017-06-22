# What are types of notification:
#  - unread document: 
#       format: Unread: Document Title
#       trigger: When document is assign to part of organization that user belongs to
#  - Panel A needs Approver
#  - Documents to Approve (for Approvers)
#  - Document is uploaded success or error
#  - Credit Card Details are invalid
class Notification
  include Mongoid::Document
  include Mongoid::Timestamps::Created

  TYPES = {
    unread_document: {
      code: "unread_document"
    },
    need_approver: {
      code: "need_approver"
    },
    document_to_approve: {
      code: "document_to_approve"
    },
    document_upload_error: {
      code: "document_upload_error"
    },
    document_upload_success: {
      code: "document_upload_success"
    },
    credit_card_invalid: {
      code: "credit_card_invalid"
    }
  }

  READ_STATUS = "Read"
  UNREAD_STATUS = "Unread"

  field :type, type: String
  field :status, type: String, default: UNREAD_STATUS
  field :path_ids, type: String
  field :lastest_type, type: String

  belongs_to :company
  belongs_to :user
  belongs_to :document

  index({user_id: 1, company_id: 1})
  index({user_id: 1, company_id: 1, status: 1})
  index({user_id: 1, company_id: 1, type: 1})
  index({user_id: 1, type: 1, document_id: 1})

  def self.when_doc_upload_finished(version)
    return unless ((doc = version.document) && (comp = doc.company))
    
    upload_type = version.box_status == "error" ? TYPES[:document_upload_error][:code] : TYPES[:document_upload_success][:code]

    admin_ids = []
    unless doc.is_private
      admin_ids = comp.user_companies.admins.pluck(:user_id)

      admin_ids.each do |a_id|
        Notification.create({user_id: a_id, company_id: comp.id, type: upload_type, 
            document_id: doc.id})
      end
    end

    Notification.create({user_id: version.user_id, company_id: comp.id, type: upload_type, 
          document_id: doc.id}) if version.user && !admin_ids.include?(version.user_id)
  end

  ##
  # When document is assigned to areas, or has new version/file
  #  create notification for accountable users
  #  - if notification is existed:
  #      - update created_at
  #      - and if user already has accountability and document has new version/file or user was just added accountability
  #         => update status of notification to unread
  #  - else
  #    create notification with unread status
  ##
  def self.when_doc_is_assign(doc, options = {})
    return unless comp = doc.company
    
    users_info = comp.user_companies.where(:company_path_ids.in => doc.approved_paths, :user_id.nin => doc.read_user_ids).pluck(:user_id, :company_path_ids)
    
    users_info.each do |u|
      noti = Notification.find_or_initialize_by({user_id: u[0], type: TYPES[:unread_document][:code], 
          document_id: doc.id})

      noti.created_at = Time.now.utc
      noti.company_id = comp.id

      new_added_paths = []
      if options[:changed_paths]
        new_added_paths = ((options[:old_paths] || []) - (options[:new_paths] || [])) rescue []
      end

      if !noti.new_record?
        if options[:new_version] || (options[:changed_paths] && new_added_paths.include?(u[1]))
          noti.status = UNREAD_STATUS
        end
      end

      noti.save 
    end
  end

  def self.when_doc_need_approve(doc)
    return unless comp = doc.company

    approver_infos = comp.user_companies.approvers.where(:approver_path_ids.in => doc.not_approved_paths ).pluck(:user_id, :approval_email_settings)
    approver_infos_hash = {}
    approver_infos.each { |e| approver_infos_hash[e[0]] = e[1] }

    approver_ids = approver_infos_hash.keys - doc.approved_by_ids

    approver_ids.each do |a_id|
      noti = Notification.find_or_initialize_by({user_id: a_id, type: TYPES[:document_to_approve][:code], 
          document_id: doc.id})

      need_sent_email = noti.new_record?

      noti.created_at = Time.now.utc
      noti.company_id = comp.id
      noti.status = UNREAD_STATUS
      noti.save

      UserMailer.delay.documents_to_approve(a_id, comp, [doc.id]) if need_sent_email && approver_infos_hash[a_id] == UserCompany::APPROVAL_EMAIL_SETTINGS[:email_instantly]
    end
  end

  def self.when_credit_card_invalid(comp)
    perm_ids = comp.permissions.where(:view_edit_company_billing_info_data_usage => true).pluck(:id)
    user_ids_can_update_comp = comp.user_companies.where(:permission_id.in => perm_ids).pluck(:user_id)

    user_ids_can_update_comp.each do |a_id|
      noti = Notification.find_or_initialize_by({user_id: a_id, company_id: comp.id, type: "credit_card_invalid"})

      noti.created_at = Time.now.utc
      noti.save
    end
  end

  def unread_document_text(docs = nil)
    doc = docs[document_id] rescue document

    I18n.t("notification.unread_document", {title: doc.title}) rescue ""
  end
    
  def need_approver_text(all_paths = nil)
    all_paths ||= company.all_paths_hash

    #node_type = company["#{lastest_type}_label".to_sym]
    path_name = all_paths[path_ids] #.split(Company::NODE_SEPARATOR).last

    I18n.t("notification.need_approver", {path_name: path_name})
  end

  def document_to_approve_text(docs = nil)
    doc = docs[document_id] rescue document

    I18n.t("notification.document_to_approve", {title: doc.title}) rescue ""
  end

  def document_upload_error_text(docs = nil)
    doc = docs[document_id] rescue document

    I18n.t("notification.document_upload_error", {title: doc.title}) rescue ""
  end

  def document_upload_success_text(docs = nil)
    doc = docs[document_id] rescue document

    I18n.t("notification.document_upload_success", {title: doc.title}) rescue ""
  end

  def credit_card_invalid_text()
    I18n.t("notification.credit_card_invalid")
  end

  ##
  # Sent daily Approval email
  # only send the email at the start of the next day (7am in there timezone)
  ##
  def self.sent_daily_approval_email
    num_emails = 0

    Company.each do |comp|
      current_time = Time.now.in_time_zone(comp.timezone)

      next if (current_time.hour != 7 && !Rails.env.test?)

      approver_infos = comp.user_companies.approvers.where(:approval_email_settings => UserCompany::APPROVAL_EMAIL_SETTINGS[:email_daily]).pluck(:user_id, :approver_path_ids)

      approver_infos.each do |approver_info|
        #find documents that can be approved by approver
        doc_ids_can_approve = comp.documents.active.where(need_approval: true, :not_approved_paths.in => approver_info[1], :approved_by_ids.nin => [approver_info[0]]).pluck(:id)

        next if doc_ids_can_approve.length == 0

        UserMailer.delay.documents_to_approve(approver_info[0], comp, doc_ids_can_approve)
        num_emails += 1
      end
    end

    num_emails
  end
end
