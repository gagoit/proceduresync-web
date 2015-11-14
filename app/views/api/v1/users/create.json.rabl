node(false) { |user| partial('api/v1/users/full_info', :object => @user)}

node(:result_code) { SUCCESS_CODES[:refresh_data] }