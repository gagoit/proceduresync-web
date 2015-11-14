node(:uid) { |doc| doc.id.to_s }
node(:title) { |doc| doc.title }

node do |doc|
	current_version = doc.current_version
	{
		:version => doc.curr_version,
		:doc_file => current_version.try(:get_pdf_url)
	}
end

if locals[:show_is_unread]
	node(:is_unread) { |doc| !(@user.read_document_ids.include?(doc.id))}
end