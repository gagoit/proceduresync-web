node(:last_timestamp) { @current_time.to_s }

node(:docs) { Document.to_json(@user, @new_docs, {show_is_unread: true, docs_need_remove_in_app: @docs_need_remove_in_app}) }

node(:result_code) { SUCCESS_CODES[:success] }
