node(:error) do |error|
	partial("api/v1/shared/error_content", :object => false)
end