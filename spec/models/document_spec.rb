# require 'spec_helper'

# describe "Document" do
# 	def clean_data
# 		Company.destroy_all
# 		User.destroy_all
# 		Category.destroy_all
# 		Document.destroy_all
# 		Version.destroy_all
# 	end

# 	def create_data
# 		clean_data
		
# 		@company = create :company
# 		@category = create :category

# 		@user = create :user

# 		@doc = create :document, category_id: @category.id, company_id: @company.id
# 		@version = create :version, document_id: @doc.id
# 	end
# 	describe "has_changed!" do
# 		context "ok" do
# 			before(:each) do
# 				create_data
# 			end

# 			it "edit version" do
# 				last_update = @doc.updated_at
# 				@version.version = "version 222"
# 				@version.save

# 				@doc.reload

# 				expect(@doc.updated_at).to_not eq(last_update)
# 			end

# 			it "edit category" do
# 				last_update = @doc.updated_at
# 				@category.name = "version 222"
# 				@category.save

# 				@doc.reload

# 				expect(@doc.updated_at).to_not eq(last_update)
# 			end
# 		end
# 	end
# end