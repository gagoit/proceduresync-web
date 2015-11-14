node(false) { @notification.to_json(@token_user)}

node(:user_push_tokens) { @user_push_tokens }

node(:result_code) { SUCCESS_CODES[:success] }