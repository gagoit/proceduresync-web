class UserDocuments::UpdateStatus

  def self.call company, user, document, options = {}
    u_comp = options.has_key?(:u_comp) ? options[:u_comp] : user.user_company(company, true)
    is_favourited = options.has_key?(:is_favourited) ? options[:is_favourited] : user.favourited_doc?(document)
    is_accountable = options.has_key?(:is_accountable) ? options[:is_accountable] : (document.private_for_id == user.id || document.approved_paths.include?(u_comp["company_path_ids"]))

    u_doc = user.company_documents(company).where({document_id: document.id})

    if u_doc.count == 0
      user.create_user_document(company, {document_id: document.id, is_favourited: is_favourited, 
        is_accountable: is_accountable})
    else
      u_doc.update_all({is_favourited: is_favourited, is_accountable: is_accountable, updated_at: Time.now.utc})
    end
  end

end