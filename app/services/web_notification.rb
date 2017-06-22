class WebNotification

  def self.create_from_user user, company
    ## Create notification in web admin for unread accountable documents
    unread_accountable_doc_ids = user.assigned_docs(company).pluck(:id)
    unread_accountable_doc_ids -= user.read_document_ids

    unread_accountable_doc_ids.each do |d_id|
      noti = Notification.find_or_initialize_by({user_id: user.id,
        type: Notification::TYPES[:unread_document][:code], document_id: d_id})

      noti.created_at = Time.now.utc
      noti.company_id = company.id
      noti.status = Notification::UNREAD_STATUS
      noti.save
    end
  end

  ##
  # Create notification in web admin for unread accountable documents
  ##
  def self.create_from_document document_id, options = {}
    document = document_id.is_a?(Document) ? document_id : Document.find(document_id)

    if !document.is_private && document.is_not_restrict_viewing
      accountable_user_ids = document.available_for_user_ids - document.read_user_ids
      accountable_user_ids.each do |u_id|
        noti = Notification.find_or_initialize_by({user_id: u_id,
          type: Notification::TYPES[:unread_document][:code], document_id: document.id})

        noti.created_at = Time.now.utc
        noti.company_id = document.company_id

        if options[:new_version] || (!noti.new_record? && (options[:new_avai_user_ids] || []).include?(u_id))
          noti.status = Notification::UNREAD_STATUS
        end

        noti.save
      end
    end
  end
end