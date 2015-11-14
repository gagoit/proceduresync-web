node(:result_code) { SUCCESS_CODES[:success] }

child @categories => :categories do
	collection @categories, :root => false, :object_root => false

	node(false) { |category| partial('api/v1/categories/info', :object => category)}
end
