require 'spec_helper'

describe "Category API" do
  before(:each) do
    create_default_data
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
        u_comp = @user.user_company(@company)
        u_comp.company_path_ids = @doc.belongs_to_paths.first
        u_comp.save
      end

      context "with one accountable doc" do
        before(:each) do
          @version1.destroy
          @doc1.destroy
        end

        it "return category info with unread_number = 1 if user has not read this doc" do
          @user.update_attribute(:read_document_ids, [])

          get 'api/categories.json', { token: @user.token }
          
          expect(json["categories"].length).to eql(1)

          expect(json["categories"][0]["name"]).to eql(@category.name)
          expect(json["categories"][0]["unread_number"]).to eql(1)

          expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
        end

        it "return category info with unread_number = 0 if user has already read this doc" do
          @user.update_attribute(:read_document_ids, [@doc.id])
          
          get 'api/categories.json', { token: @user.token }
          
          expect(json["categories"].length).to eql(1)

          expect(json["categories"][0]["name"]).to eql(@category.name)
          expect(json["categories"][0]["unread_number"]).to eql(0)
        end
      end
    end

    context "success when has two categories" do
      before(:each) do
        @category1 = create :category, company_id: @company.id
      end

      context "and each category has one accountable doc" do
        before(:each) do
          @doc1.category = @category1
          @doc1.belongs_to_paths << @doc.belongs_to_paths.first
          @doc1.save

          u_comp = @user.user_company(@company)
          u_comp.company_path_ids = @doc.belongs_to_paths.first
          u_comp.save
        end

        it "return category info with correct unread_number for each category if user has not read these docs" do
          @user.update_attribute(:read_document_ids, [])

          get 'api/categories.json', { token: @user.token }
          
          expect(json["categories"].length).to eql(2)

          expect(json["categories"][0]["name"]).to eql(@category.name)
          expect(json["categories"][0]["unread_number"]).to eql(1)

          expect(json["categories"][1]["name"]).to eql(@category1.name)
          expect(json["categories"][1]["unread_number"]).to eql(1)
        end

        it "return category info with correct unread_number for each category if user has read a doc" do
          @user.update_attribute(:read_document_ids, [@doc.id])

          get 'api/categories.json', { token: @user.token }
          
          expect(json["categories"].length).to eql(2)

          expect(json["categories"][0]["name"]).to eql(@category.name)
          expect(json["categories"][0]["unread_number"]).to eql(0)

          expect(json["categories"][1]["name"]).to eql(@category1.name)
          expect(json["categories"][1]["unread_number"]).to eql(1)
        end

        it "return correct category info when it has more than one accountable docs" do
          @doc2 = create :document, category_id: @category.id, company_id: @company.id, belongs_to_paths: [@all_paths.keys.first]
          @version2 = create :version, document_id: @doc2.id, box_status: "done", box_file_size: 100
          
          @doc2.curr_version = @version2.version
          @doc1.belongs_to_paths << @doc.belongs_to_paths.first
          @doc2.save

          get 'api/categories.json', { token: @user.token }
          
          expect(json["categories"].length).to eql(2)

          expect(json["categories"][0]["name"]).to eql(@category.name)
          expect(json["categories"][0]["unread_number"]).to eql(2)

          expect(json["categories"][1]["name"]).to eql(@category1.name)
          expect(json["categories"][1]["unread_number"]).to eql(1)
        end
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
    context "when category has only one doc and it's accountable for user" do
      before(:each) do
        @category1 = create :category, company_id: @company.id
        @doc1.category = @category1
        @doc1.save

        u_comp = @user.user_company(@company)
        u_comp.company_path_ids = @doc.belongs_to_paths.first
        u_comp.save
      end

      it "return doc info with is_unread = true if user has not read this doc yet" do

        get 'api/category/docs.json', {token: @user.token, category_id: @category.id.to_s}
        
        expect(json["docs"].length).to eq(1)

        cate_docs = json["docs"]

        CheckReturnDocInfo.new.test(cate_docs[0], @doc)

        expect(cate_docs[0]["is_unread"]).to eq(true)
        expect(cate_docs[0]["is_favourite"]).to eq(false)

        expect(json["unread_number"]).to eq(1)

        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
      end

      it "return doc info with is_unread = false if user has already read this doc" do
        @user.update_attribute(:read_document_ids, [@doc.id])

        get 'api/category/docs.json', {token: @user.token, category_id: @category.id.to_s}
        
        expect(json["docs"].length).to eq(1)

        cate_docs = json["docs"]

        CheckReturnDocInfo.new.test(cate_docs[0], @doc)
        expect(cate_docs[0]["is_unread"]).to eq(false)
        expect(cate_docs[0]["is_favourite"]).to eq(false)

        expect(json["unread_number"]).to eq(0)
      end
    end

    context "when category has only one doc and it isn't accountable for user" do
      before(:each) do
        @category1 = create :category, company_id: @company.id
        @doc1.category = @category1
        @doc1.save

        u_comp = @user.user_company(@company)
        u_comp.company_path_ids = @doc1.belongs_to_paths.first
        u_comp.save
      end

      it "always return doc info with is_unread = false if user read/not read this doc" do

        get 'api/category/docs.json', {token: @user.token, category_id: @category.id.to_s}
        
        expect(json["docs"].length).to eq(1)

        cate_docs = json["docs"]

        CheckReturnDocInfo.new.test(cate_docs[0], @doc)

        expect(cate_docs[0]["is_unread"]).to eq(false)
        expect(cate_docs[0]["is_favourite"]).to eq(false)

        expect(json["unread_number"]).to eq(0)

        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
      end
    end

    context "when category has two docs and all are accountable for user" do
      before(:each) do
        u_comp = @user.user_company(@company)
        u_comp.company_path_ids = @doc.belongs_to_paths.first
        u_comp.save
        u_comp.reload

        @doc1.belongs_to_paths << @doc.belongs_to_paths.first
        @doc1.category = @category
        @doc1.save
      end

      it "return doc info with is_unread = true if user has not read them" do
        @user.update_attribute(:read_document_ids, [])

        get 'api/category/docs.json', {token: @user.token, category_id: @category.id.to_s}
        
        expect(json["docs"].length).to eq(2)

        cate_docs = json["docs"]

        CheckReturnDocInfo.new.test(cate_docs[0], @doc1)
        expect(cate_docs[0]["is_unread"]).to eq(true)
        expect(cate_docs[0]["is_favourite"]).to eq(false)

        CheckReturnDocInfo.new.test(cate_docs[1], @doc)
        expect(cate_docs[1]["is_unread"]).to eq(true)
        expect(cate_docs[1]["is_favourite"]).to eq(false)

        expect(json["unread_number"]).to eq(2)
      end

      it "return doc info with correct is_unread status for each doc if user has read one of them" do
        @user.update_attribute(:read_document_ids, [@doc.id])

        get 'api/category/docs.json', {token: @user.token, category_id: @category.id.to_s}
        
        expect(json["docs"].length).to eq(2)

        cate_docs = json["docs"]

        CheckReturnDocInfo.new.test(cate_docs[0], @doc1)
        expect(cate_docs[0]["is_unread"]).to eq(true)
        expect(cate_docs[0]["is_favourite"]).to eq(false)

        CheckReturnDocInfo.new.test(cate_docs[1], @doc)
        expect(cate_docs[1]["is_unread"]).to eq(false)
        expect(cate_docs[1]["is_favourite"]).to eq(false)

        expect(json["unread_number"]).to eq(1)
      end

      it "when has two docs & one doc is inactive" do
        @category.update_attribute(:document_ids, [@doc.id, @doc1.id])
        @doc.update_attribute(:active, false)

        get 'api/category/docs.json', {token: @user.token, category_id: @category.id.to_s}
        
        expect(json["docs"].length).to eq(2)

        cate_docs = json["docs"]

        CheckReturnDocInfo.new.test(cate_docs[0], @doc1)
        expect(cate_docs[0]["is_unread"]).to eq(true)
        expect(cate_docs[0]["is_inactive"]).to eq(false)
        expect(cate_docs[0]["is_favourite"]).to eq(false)

        CheckReturnDocInfo.new.test(cate_docs[1], @doc)
        expect(cate_docs[1]["is_unread"]).to eq(true)
        expect(cate_docs[1]["is_inactive"]).to eq(true)
        expect(cate_docs[1]["is_favourite"]).to eq(false)

        expect(json["unread_number"]).to eq(1)
      end
    end

    context "when category has two docs and all are not accountable for user" do
      before(:each) do
        @doc1.belongs_to_paths << @doc.belongs_to_paths.first
        @doc1.category = @category
        @doc1.save

        u_comp = @user.user_company(@company)
        u_comp.company_path_ids = (@all_paths.keys - @doc.belongs_to_paths - @doc1.belongs_to_paths).first
        u_comp.save
        u_comp.reload
      end

      it "always return doc info with is_unread = false if user read/not read them" do
        @user.update_attribute(:read_document_ids, [])

        get 'api/category/docs.json', {token: @user.token, category_id: @category.id.to_s}
        
        expect(json["docs"].length).to eq(2)

        cate_docs = json["docs"]

        CheckReturnDocInfo.new.test(cate_docs[0], @doc1)
        expect(cate_docs[0]["is_unread"]).to eq(false)
        expect(cate_docs[0]["is_favourite"]).to eq(false)

        CheckReturnDocInfo.new.test(cate_docs[1], @doc)
        expect(cate_docs[1]["is_unread"]).to eq(false)
        expect(cate_docs[1]["is_favourite"]).to eq(false)

        expect(json["unread_number"]).to eq(0)
      end
    end

    context "when has no doc" do

      it "return empty" do
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
