node(:result_code) { SUCCESS_CODES[:success] }

child @users => :users do
	collection @users, :root => false, :object_root => false

	node(false) { |user| partial('api/v1/users/full_info', :object => user)}
end

