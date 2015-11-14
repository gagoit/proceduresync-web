module DocumentHelper

  def document_info(doc, version = nil)
    version ||= doc.current_version
    
    infos = []
    infos << "ID #{doc.doc_id}" if doc.doc_id
    infos << version.version
    infos << BaseService.time_formated(current_company, doc.created_time, I18n.t("date.format"))
    infos << (doc.category_name.blank? ? 'Private' : doc.category_name)
    infos << "Expires #{BaseService.time_formated(current_company, doc.expiry, I18n.t('date.format') )}" if doc.expiry

    infos.join(" • ")
  end
end