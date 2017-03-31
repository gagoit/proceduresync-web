require 'spec_helper'

describe "Document API" do
  before(:each) do
    create_default_data({create_doc: false})
  end

  ##
  # Search Documents
  # /docs.json
  # GET
  # @params: 
  #   search_term
  # @response:  
  #   { 
  #     docs: [ { uid, title, doc_file, version, is_unread, is_inactive, is_favourite, category } ] 
  #   }
  describe "GET /docs.json" do
    context "search in title" do
      before(:each) do
        @doc, version = create_doc(@company, {document: {title: "Document AA", doc_id: "TT", category_id: @category.id}, version: {}})
        @doc1, version1 = create_doc(@company, {document: {title: "Document BB", doc_id: "YY", category_id: @category.id}, version: {}})
      end

      it "when search_term doesn't match with any documents" do
        get 'api/docs.json', {token: @user.token, search_term: "12", company_id: @company.id}
        
        expect(json["docs"].length).to eq(0)
      end

      it "when search_term match with one document" do
        get 'api/docs.json', {token: @user.token, search_term: "aa", company_id: @company.id}
        
        expect(json["docs"].length).to eq(1)

        cate_docs = json["docs"]

        CheckReturnDocInfo.new.test(cate_docs[0], @doc)
        # expect(cate_docs[0]["is_unread"]).to eq(true)
        expect(cate_docs[0]["is_favourite"]).to eq(false)

        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
      end

      it "when search_term match with two documents" do
        get 'api/docs.json', {token: @user.token, search_term: "document", company_id: @company.id}
        
        expect(json["docs"].length).to eq(2)

        cate_docs = json["docs"]

        CheckReturnDocInfo.new.test(cate_docs[0], @doc)
        # expect(cate_docs[0]["is_unread"]).to eq(true)
        expect(cate_docs[0]["is_favourite"]).to eq(false)

        CheckReturnDocInfo.new.test(cate_docs[1], @doc1)
        # expect(cate_docs[1]["is_unread"]).to eq(true)
        expect(cate_docs[1]["is_favourite"]).to eq(false)
      end
    end

    context "search in doc_id" do
      before(:each) do
        @doc, version = create_doc(@company, {document: {title: "AA", doc_id: "Code EE", category_id: @category.id}, version: {}})
        @doc1, version1 = create_doc(@company, {document: {title: "BB", doc_id: "Code DD", category_id: @category.id}, version: {}})
      end

      it "when search_term doesn't match with any documents" do
        @category.update_attribute(:document_ids, [@doc.id])

        get 'api/docs.json', {token: @user.token, search_term: "12", company_id: @company.id}
        
        expect(json["docs"].length).to eq(0)
      end

      it "when search_term match with one document" do
        get 'api/docs.json', {token: @user.token, search_term: "ee", company_id: @company.id}
        
        expect(json["docs"].length).to eq(1)

        cate_docs = json["docs"]

        CheckReturnDocInfo.new.test(cate_docs[0], @doc)
        # expect(cate_docs[0]["is_unread"]).to eq(true)
        expect(cate_docs[0]["is_favourite"]).to eq(false)
      end

      it "when search_term match with two documents" do
        get 'api/docs.json', {token: @user.token, search_term: "code", company_id: @company.id}
        
        expect(json["docs"].length).to eq(2)

        cate_docs = json["docs"]

        CheckReturnDocInfo.new.test(cate_docs[0], @doc)
        # expect(cate_docs[0]["is_unread"]).to eq(true)
        expect(cate_docs[0]["is_favourite"]).to eq(false)

        CheckReturnDocInfo.new.test(cate_docs[1], @doc1)
        # expect(cate_docs[1]["is_unread"]).to eq(true)
        expect(cate_docs[1]["is_favourite"]).to eq(false)
      end
    end
  end

end