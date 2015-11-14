node(false) { |user| partial('api/v1/users/full_info', :object => @user, :locals => {:show_token => true})}

node(:result_code) { SUCCESS_CODES[:refresh_data] }