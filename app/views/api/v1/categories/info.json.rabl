node(:uid) { |category| category.id.to_s }
node(:name) { |category| category.name }

node(:unread_number) { |category| category.unread_number(@user) }