if defined?(@error_code) && @error_code
	node(:error_code) { @error_code }
else
	node(:error_code) { ERROR_CODES[:unknown] }
end

node(:message) {@error}

node(:debugDesc) {(@debugDesc || "")}
