node(:unread_number) { @result[:unread_number] }

node(:docs) { Document.to_json(@user, @result[:docs], {show_is_unread: true}) }

node(:result_code) { SUCCESS_CODES[:success] }
