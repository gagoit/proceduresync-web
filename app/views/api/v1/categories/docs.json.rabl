node(:unread_number) { @category.unread_number(@user) }

node(:docs) { Document.to_json(@user, @category.documents, {show_is_unread: true}) }

node(:result_code) { SUCCESS_CODES[:success] }
