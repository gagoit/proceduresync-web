node(:uid) { |user| user.id.to_s }

attributes :name, :has_setup, :home_email, :email, :has_reset_pass

node(:companies) { |user| Company.basic_json(user.companies.active) }

if locals[:show_token]
	node(:token) { |user| user.token }
end

node(:total_docs_size) { |user| user.total_docs_size }

node(:has_report) { |user| user.can_see_report_ws }