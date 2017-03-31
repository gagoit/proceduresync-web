require 'spec_helper'

describe "Document API" do
  before(:each) do
    create_default_data
  end

  ##
  # Mark all docs as read
  # /docs/mark_all_as_read.json
  # POST
  # @params: 
  #   token
  # @response:  
  #   {result: true}
  describe "POST /docs/mark_all_as_read.json" do
    context "render success" do

      context "with accountable docs have been marked as read" do
        before(:each) do
          @user.add_company(@company, {company_path_ids: @doc.belongs_to_paths.first})
        end

        it "when accountable doc(s) is/are not expiried" do
          post 'api/docs/mark_all_as_read.json', {token: @user.token}
          
          expect(json["result"]).to eql(true)

          @user.reload
          expect(@user.read_document_ids.include?(@doc.id)).to eq(true)

          expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
        end

        it "when user has many companies, accountable docs" do
          company1 = create :company, name: "fdasfsdfds"
          category11 = create :category, company_id: company1.id
          comp_node = company1.company_structures.where(type: "company", name: company1.name).first

          division_node_1 = company1.company_structures.create({type: 'division', name: "Division 1", 
                      parent_id: comp_node.id})

          doc1 = create :document, company_id: company1.id, category_id: category11.id, belongs_to_paths: [division_node_1.path]
          version = create :version, document_id: doc1.id

          @user.company_ids << company1.id
          @user.save
          @user.reload
          company1.reload

          User.update_companies_of_user(@user, [@company.id], @user.company_ids)
          u_comp = @user.user_company(company1)
          u_comp.company_path_ids = division_node_1.path
          u_comp.save

          @user.reload

          post 'api/docs/mark_all_as_read.json', { token: @user.token}

          @user.reload
          expect(@user.read_document_ids.include?(@doc.id)).to eq(true)
          expect(@user.read_document_ids.include?(doc1.id)).to eq(true)

          expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
        end
      end

      context "with un-accountable docs have been not marked as read" do

        it "when accountable doc(s) is/are not expiried" do
          post 'api/docs/mark_all_as_read.json', {token: @user.token}
          
          expect(json["result"]).to eql(true)

          @user.reload
          expect(@user.read_document_ids.include?(@doc.id)).to eq(false)

          expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
        end

        it "when user has many companies, un-accountable docs" do
          company1 = create :company, name: "fdasfsdfds"
          category11 = create :category, company_id: company1.id
          comp_node = company1.company_structures.where(type: "company", name: company1.name).first

          division_node_1 = company1.company_structures.create({type: 'division', name: "Division 1", 
                      parent_id: comp_node.id})

          doc1 = create :document, company_id: company1.id, category_id: category11.id, belongs_to_paths: [division_node_1.path]
          version = create :version, document_id: doc1.id

          @user.company_ids << company1.id
          @user.save

          post 'api/docs/mark_all_as_read.json', { token: @user.token}

          @user.reload
          expect(@user.read_document_ids.include?(@doc.id)).to eq(false)
          expect(@user.read_document_ids.include?(doc1.id)).to eq(false)

          expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
        end
      end
    end
  end
end
