require 'spec_helper'

describe "Category API" do
  before(:each) do
    Company.destroy_all
    
    @company = create :company
  end
  ##
  # Categories
  # /categories.json
  # GET
  # @params: 
  #   token
  # @response:  
  #   { 
  #     categories: [ 
  #        {  name, unread_number  } 
  #     ] 
  #   }
  describe "GET categories.json" do
    context "success when has only one category" do
      before(:each) do
        User.destroy_all
        Document.destroy_all
        Version.destroy_all
        Category.destroy_all

        @user = create :user, company_ids: [@company.id]
        @category = create :category

        @doc = create :document, company_id: @company.id, category_id: @category.id
        version = create :version, document_id: @doc.id
      end

      it "with one doc and user has not read this doc" do
        @user.update_attribute(:read_document_ids, [])

        get 'api/categories.json', { token: @user.token }
        
        expect(json["categories"].length).to eql(1)

        cate = json["categories"][0]

        expect(cate["name"]).to eql(@category.name)
        expect(cate["unread_number"]).to eql(@category.unread_number(@user))

        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
      end

      it "with one doc and user has already read this doc" do
        @user.update_attribute(:read_document_ids, [@doc.id])
        
        get 'api/categories.json', { token: @user.token }
        
        expect(json["categories"].length).to eql(1)

        cate = json["categories"][0]

        expect(cate["name"]).to eql(@category.name)
        expect(cate["unread_number"]).to eql(@category.unread_number(@user))
      end
    end

    context "success when has two categories" do
      before(:each) do
        User.destroy_all
        Document.destroy_all
        Version.destroy_all
        Category.destroy_all

        @user = create :user, company_ids: [@company.id]
        @category = create :category, name: "Category 1"
        @category1 = create :category, name: "Category 2"

        @doc = create :document, company_id: @company.id, category_id: @category.id
        version = create :version, document_id: @doc.id

        @doc1 = create :document, company_id: @company.id, category_id: @category1.id
        version1 = create :version, document_id: @doc1.id
      end

      it "with each category has one doc and user has not read these docs" do
        @user.update_attribute(:read_document_ids, [])

        get 'api/categories.json', { token: @user.token }
        
        expect(json["categories"].length).to eql(2)

        cate1 = json["categories"][0]

        expect(cate1["name"]).to eql(@category.name)
        expect(cate1["unread_number"]).to eql(@category.unread_number(@user))

        cate2 = json["categories"][1]

        expect(cate2["name"]).to eql(@category1.name)
        expect(cate2["unread_number"]).to eql(@category1.unread_number(@user))
      end

      it "with each category has one doc and user has read a doc" do
        @user.update_attribute(:read_document_ids, [@doc.id])

        get 'api/categories.json', { token: @user.token }
        
        expect(json["categories"].length).to eql(2)

        cate1 = json["categories"][0]

        expect(cate1["name"]).to eql(@category.name)
        expect(cate1["unread_number"]).to eql(@category.unread_number(@user))

        cate2 = json["categories"][1]

        expect(cate2["name"]).to eql(@category1.name)
        expect(cate2["unread_number"]).to eql(@category1.unread_number(@user))
      end

      it "with category 1 has more than one docs" do
        @doc2 = create :document, company_id: @company.id, category_id: @category.id
        version2 = create :version, document_id: @doc2.id

        @category.document_ids << @doc2.id
        @category.save

        get 'api/categories.json', { token: @user.token }
        
        expect(json["categories"].length).to eql(2)

        cate1 = json["categories"][0]

        expect(cate1["name"]).to eql(@category.name)
        expect(cate1["unread_number"]).to eql(@category.unread_number(@user))

        cate2 = json["categories"][1]

        expect(cate2["name"]).to eql(@category1.name)
        expect(cate2["unread_number"]).to eql(@category1.unread_number(@user))
      end
    end
  end


  ##
  # Get docs for a  Category
  # /category/docs.json
  # GET
  # @params: 
  #   token, category_id
  # @response:  
  #   { 
  #     docs: [ { uid, title, doc_file, version, is_unread } ], 
  #     unread_number 
  #   }
  describe "GET /category/docs.json" do
    context "success" do
      before(:each) do
        User.destroy_all
        Document.destroy_all
        Version.destroy_all
        Category.destroy_all

        @user = create :user, company_ids: [@company.id]
        @category = create :category, name: "Category 1"
        @category1 = create :category, name: "Category 2"

        @doc = create :document, company_id: @company.id, category_id: @category.id
        version = create :version, document_id: @doc.id

        @doc1 = create :document, company_id: @company.id, category_id: @category1.id
        version1 = create :version, document_id: @doc1.id
      end

      it "when category has only one doc and user has not read this doc yet" do

        get 'api/category/docs.json', {token: @user.token, category_id: @category.id.to_s}
        
        expect(json["docs"].length).to eq(1)

        cate_docs = json["docs"]

        expect(cate_docs[0]["uid"]).to eq(@doc.id.to_s)
        expect(cate_docs[0]["title"]).to eq(@doc.title)
        expect(cate_docs[0]["doc_file"]).to eq(@doc.current_version.doc_file)
        expect(cate_docs[0]["version"]).to eq(@doc.current_version.version)
        expect(cate_docs[0]["is_unread"]).to eq(true)

        expect(cate_docs[0]["is_favourite"]).to eq(false)
        expect(cate_docs[0]["category"]).to eq(@doc.reload.category.try(:name).to_s)

        expect(json["unread_number"]).to eq(1)

        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
      end

      it "when category has only one doc and user has already read this doc" do
        @user.update_attribute(:read_document_ids, [@doc.id])

        get 'api/category/docs.json', {token: @user.token, category_id: @category.id.to_s}
        
        expect(json["docs"].length).to eq(1)

        cate_docs = json["docs"]

        expect(cate_docs[0]["uid"]).to eq(@doc.id.to_s)
        expect(cate_docs[0]["title"]).to eq(@doc.title)
        expect(cate_docs[0]["doc_file"]).to eq(@doc.current_version.doc_file)
        expect(cate_docs[0]["version"]).to eq(@doc.current_version.version)
        expect(cate_docs[0]["is_unread"]).to eq(false)

        expect(cate_docs[0]["is_favourite"]).to eq(false)
        expect(cate_docs[0]["category"]).to eq(@doc.reload.category.try(:name).to_s)

        expect(json["unread_number"]).to eq(0)
      end

      it "when has two docs & user has not read them" do
        @category.update_attribute(:document_ids, [@doc.id, @doc1.id])
        @user.update_attribute(:read_document_ids, [])

        get 'api/category/docs.json', {token: @user.token, category_id: @category.id.to_s}
        
        expect(json["docs"].length).to eq(2)

        cate_docs = json["docs"]

        expect(cate_docs[0]["uid"]).to eq(@doc1.id.to_s)
        expect(cate_docs[0]["title"]).to eq(@doc1.title)
        expect(cate_docs[0]["doc_file"]).to eq(@doc1.current_version.doc_file)
        expect(cate_docs[0]["version"]).to eq(@doc1.current_version.version)
        expect(cate_docs[0]["is_unread"]).to eq(true)

        expect(cate_docs[0]["is_favourite"]).to eq(false)
        expect(cate_docs[0]["category"]).to eq(@doc1.reload.category.try(:name).to_s)

        expect(cate_docs[1]["uid"]).to eq(@doc.id.to_s)
        expect(cate_docs[1]["title"]).to eq(@doc.title)
        expect(cate_docs[1]["doc_file"]).to eq(@doc.current_version.doc_file)
        expect(cate_docs[1]["version"]).to eq(@doc.current_version.version)
        expect(cate_docs[1]["is_unread"]).to eq(true)

        expect(cate_docs[0]["is_favourite"]).to eq(false)
        expect(cate_docs[0]["category"]).to eq(@doc.reload.category.try(:name).to_s)

        expect(json["unread_number"]).to eq(2)
      end

      it "when has two docs & user has read one of them" do
        @category.update_attribute(:document_ids, [@doc.id, @doc1.id])
        @user.update_attribute(:read_document_ids, [@doc.id])

        get 'api/category/docs.json', {token: @user.token, category_id: @category.id.to_s}
        
        expect(json["docs"].length).to eq(2)

        cate_docs = json["docs"]

        expect(cate_docs[0]["uid"]).to eq(@doc1.id.to_s)
        expect(cate_docs[0]["title"]).to eq(@doc1.title)
        expect(cate_docs[0]["doc_file"]).to eq(@doc1.current_version.doc_file)
        expect(cate_docs[0]["version"]).to eq(@doc1.current_version.version)
        expect(cate_docs[0]["is_unread"]).to eq(true)

        expect(cate_docs[0]["is_favourite"]).to eq(false)
        expect(cate_docs[0]["category"]).to eq(@doc1.reload.category.try(:name).to_s)

        expect(cate_docs[1]["uid"]).to eq(@doc.id.to_s)
        expect(cate_docs[1]["title"]).to eq(@doc.title)
        expect(cate_docs[1]["doc_file"]).to eq(@doc.current_version.doc_file)
        expect(cate_docs[1]["version"]).to eq(@doc.current_version.version)
        expect(cate_docs[1]["is_unread"]).to eq(false)

        expect(cate_docs[0]["is_favourite"]).to eq(false)
        expect(cate_docs[0]["category"]).to eq(@doc.reload.category.try(:name).to_s)

        expect(json["unread_number"]).to eq(1)
      end

      it "when has two docs & one doc is inactive" do
        @category.update_attribute(:document_ids, [@doc.id, @doc1.id])
        @doc.update_attribute(:active, false)

        get 'api/category/docs.json', {token: @user.token, category_id: @category.id.to_s}
        
        expect(json["docs"].length).to eq(2)

        cate_docs = json["docs"]

        expect(cate_docs[0]["uid"]).to eq(@doc1.id.to_s)
        expect(cate_docs[0]["title"]).to eq(@doc1.title)
        expect(cate_docs[0]["doc_file"]).to eq(@doc1.current_version.doc_file)
        expect(cate_docs[0]["version"]).to eq(@doc1.current_version.version)
        expect(cate_docs[0]["is_unread"]).to eq(true)
        expect(cate_docs[0]["is_inactive"]).to eq(false)

        expect(cate_docs[0]["is_favourite"]).to eq(false)
        expect(cate_docs[0]["category"]).to eq(@doc1.reload.category.try(:name).to_s)

        expect(cate_docs[1]["uid"]).to eq(@doc.id.to_s)
        expect(cate_docs[1]["title"]).to eq(@doc.title)
        expect(cate_docs[1]["doc_file"]).to eq(@doc.current_version.doc_file)
        expect(cate_docs[1]["version"]).to eq(@doc.current_version.version)
        expect(cate_docs[1]["is_unread"]).to eq(true)
        expect(cate_docs[1]["is_inactive"]).to eq(true)

        expect(cate_docs[0]["is_favourite"]).to eq(false)
        expect(cate_docs[0]["category"]).to eq(@doc.reload.category.try(:name).to_s)

        expect(json["unread_number"]).to eq(1)
      end

      it "when has no doc" do
        @category.update_attribute(:document_ids, [])

        get 'api/category/docs.json', {token: @user.token, category_id: @category.id.to_s}
        
        expect(json["docs"].length).to eq(0)
        expect(json["unread_number"]).to eq(0)
      end
    end

    context "error" do
      before(:each) do
        User.destroy_all
        Document.destroy_all
        Version.destroy_all
        Category.destroy_all

        @user = create :user, company_ids: [@company.id]
      end

      it "when category is not found" do
        get 'api/category/docs.json', {token: @user.token, category_id: "sa"}
        
        expect(json["error"]["message"]).to eq(I18n.t("category.not_found"))
        expect(json["error"]["error_code"]).to eq(ERROR_CODES[:item_not_found])
      end
    end
  end
end
