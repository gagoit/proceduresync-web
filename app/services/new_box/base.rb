require 'boxr'

module NewBox::Base

  def client
    @client ||= Boxr::Client.new(CONFIG[:box_view_access_token])
  end

  def documents_folder
    @documents_folder ||= NewBox::FindFolder.call("documents")
  end

  def get_document_folder(doc_id)
    document_folder = NewBox::CreateFolder.call(doc_id.to_s, documents_folder)
    document_folder ||= NewBox::FindFolder.call("documents/#{doc_id}")
  end

  def get_static_files_folder
    folder = NewBox::CreateFolder.call("static_files")
    folder ||= NewBox::FindFolder.call("static_files")
  end
end