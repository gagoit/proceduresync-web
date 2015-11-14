node(:docs) { Document.to_json(@user, @documents, {show_is_unread: true}) }

node(:result_code) { SUCCESS_CODES[:success] }
