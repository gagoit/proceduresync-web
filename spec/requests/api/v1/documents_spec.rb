require 'spec_helper'

describe "Document API" do
  before(:each) do
    Company.destroy_all
    Category.destroy_all
    
    @company = create :company
    @category = create :category
  end
  ##
  # Mark a doc as favourite
  # /docs/favourite.json
  # POST
  # @params: 
  #   doc_id
  # @response:  
  #   {result: true}
  describe "POST /docs/favourite.json" do
    context "success" do
      before(:each) do
        User.destroy_all
        Document.destroy_all
        Version.destroy_all
        Delayed::Job.destroy_all

        @user = create :user, company_ids: [@company.id]
        @doc = create :document, company_id: @company.id, category_id: @category.id
        version = create :version, document_id: @doc.id
      end

      it "when doc isn't expiried & user has not favourited this doc yet" do
        post 'api/docs/favourite.json', { doc_id: @doc.id.to_s, token: @user.token, type: "favourite", company_id: @company.id}
        
        expect(json["result"]).to eql(true)

        @user.reload
        expect(@user.favourite_document_ids.include?(@doc.id)).to eq(true)

        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
      end
    end

    context "errors" do
      before(:each) do
        User.destroy_all
        Document.destroy_all
        Version.destroy_all
        Delayed::Job.destroy_all

        @user = create :user, company_ids: [@company.id]
        @doc = create :document, company_id: @company.id, category_id: @category.id
        version = create :version, document_id: @doc.id
      end

      it "when doc is expiried" do
        @doc.update_attribute(:expiry, (Time.now - 1.day).utc)
        post 'api/docs/favourite.json', { doc_id: @doc.id.to_s, token: @user.token, type: "favourite", company_id: @company.id}
        
        expect(json["result"]).to eql(nil)
        expect(json["error"]["message"]).to eql(I18n.t("document.is_expiried"))
        expect(json["error"]["error_code"]).to eq(ERROR_CODES[:refresh_data])

        @user.reload
        expect(@user.favourite_document_ids.include?(@doc.id)).to eq(false)
      end

      it "when user do this action offline and doc has been changed when user online" do
        post 'api/docs/favourite.json', { doc_id: @doc.id.to_s, token: @user.token, type: "favourite", company_id: @company.id}

        post 'api/docs/favourite.json', { doc_id: @doc.id.to_s, token: @user.token, type: "favourite", company_id: @company.id, action_time: (Time.now - 1.day).utc.to_s}
        
        expect(json["result"]).to eql(true)
        expect(json["result_code"]).to eql(SUCCESS_CODES[:rejected])
        expect(json["is_favourite"]).to eq(@user.reload.favourited_doc?(@doc))
      end

      it "when doc is private" do
        @user1 = create :user, token: "fdsfdsf"
        @doc.update_attributes({is_private: true, private_for_id: @user1.id})

        post 'api/docs/favourite.json', { doc_id: @doc.id.to_s, token: @user.token, type: "favourite", company_id: @company.id}
        
        expect(json["result"]).to eql(nil)
        expect(json["error"]["message"]).to eql(I18n.t("document.is_private"))
        expect(json["error"]["error_code"]).to eq(ERROR_CODES[:refresh_data])

        @user.reload
        expect(@user.favourite_document_ids.include?(@doc.id)).to eq(false)
      end

      it "when doc has already been favourited by user" do
        @user.favourite_document_ids = [@doc.id]
        @user.save

        post 'api/docs/favourite.json', { doc_id: @doc.id.to_s, token: @user.token, type: "favourite", company_id: @company.id}
        
        expect(json["result"]).to eql(nil)
        expect(json["error"]["message"]).to eql(I18n.t("document.already_favour_before"))
        expect(json["error"]["error_code"]).to eq(ERROR_CODES[:invalid_value])

        @user.reload
        expect(@user.favourite_document_ids.include?(@doc.id)).to eq(true)
      end

      it "when doc is not found" do
        post 'api/docs/favourite.json', { doc_id: "#{@doc.id.to_s}11", token: @user.token, type: "favourite", company_id: @company.id}
        
        expect(json["result"]).to eql(nil)
        expect(json["error"]["message"]).to eql(I18n.t("document.not_found"))
        expect(json["error"]["error_code"]).to eq(ERROR_CODES[:item_not_found])

        @user.reload
        expect(@user.favourite_document_ids.include?(@doc.id)).to eq(false)
      end
    end
  end


  ##
  # Remove doc from favourites list
  # /docs/unfavourite.json
  # POST
  # @params: 
  #   doc_id
  # @response:  
  #   {result: true}
  describe "POST /docs/favourite.json" do
    context "success" do
      before(:each) do
        User.destroy_all
        Document.destroy_all
        Version.destroy_all
        Delayed::Job.destroy_all

        @user = create :user, company_ids: [@company.id]
        @doc = create :document, company_id: @company.id, category_id: @category.id
        version = create :version, document_id: @doc.id
      end

      it "when doc isn't expiried & user has already favourited this doc" do
        @user.favourite_document_ids = [@doc.id]
        @user.save

        post 'api/docs/favourite.json', { doc_id: @doc.id.to_s, token: @user.token, type: "unfavourite", company_id: @company.id}
        
        expect(json["result"]).to eql(true)

        @user.reload
        expect(@user.favourite_document_ids.include?(@doc.id)).to eq(false)

        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
      end

      it "when user do this action offline and doc has been changed when user online" do
        post 'api/docs/favourite.json', { doc_id: @doc.id.to_s, token: @user.token, type: "favourite", company_id: @company.id}
        post 'api/docs/favourite.json', { doc_id: @doc.id.to_s, token: @user.token, type: "unfavourite", company_id: @company.id}

        post 'api/docs/favourite.json', { doc_id: @doc.id.to_s, token: @user.token, type: "unfavourite", company_id: @company.id, action_time: (Time.now - 1.day).utc.to_s}
        
        expect(json["result"]).to eql(true)
        expect(json["result_code"]).to eql(SUCCESS_CODES[:rejected])
        expect(json["is_favourite"]).to eq(@user.reload.favourited_doc?(@doc))
      end
    end

    context "errors" do
      before(:each) do
        User.destroy_all
        Document.destroy_all
        Version.destroy_all
        Delayed::Job.destroy_all

        @user = create :user, company_ids: [@company.id]
        @doc = create :document, company_id: @company.id, category_id: @category.id
        version = create :version, document_id: @doc.id

        @user.favourite_document_ids = [@doc.id]
        @user.save
      end

      it "when doc is expiried" do
        @doc.update_attribute(:expiry, (Time.now - 1.day).utc)
        post 'api/docs/favourite.json', { doc_id: @doc.id.to_s, token: @user.token, type: "unfavourite", company_id: @company.id}
        
        expect(json["result"]).to eql(nil)
        expect(json["error"]["message"]).to eql(I18n.t("document.is_expiried"))
        expect(json["error"]["error_code"]).to eq(ERROR_CODES[:refresh_data])

        @user.reload
        expect(@user.favourite_document_ids.include?(@doc.id)).to eq(true)
      end

      it "when doc is private" do
        @user1 = create :user, token: "fdsfdsf", company_ids: [@company.id]
        @doc.update_attributes({is_private: true, private_for_id: @user1.id})

        post 'api/docs/favourite.json', { doc_id: @doc.id.to_s, token: @user.token, type: "unfavourite", company_id: @company.id}
        
        expect(json["result"]).to eql(nil)
        expect(json["error"]["message"]).to eql(I18n.t("document.is_private"))
        expect(json["error"]["error_code"]).to eq(ERROR_CODES[:refresh_data])

        @user.reload
        expect(@user.favourite_document_ids.include?(@doc.id)).to eq(true)
      end

      it "when doc has not been favourited by user yet" do
        @user.favourite_document_ids = []
        @user.save

        post 'api/docs/favourite.json', { doc_id: @doc.id.to_s, token: @user.token, type: "unfavourite", company_id: @company.id}
        
        expect(json["result"]).to eql(nil)
        expect(json["error"]["message"]).to eql(I18n.t("document.not_favour_before"))
        expect(json["error"]["error_code"]).to eq(ERROR_CODES[:invalid_value])

        @user.reload
        expect(@user.favourite_document_ids.include?(@doc.id)).to eq(false)
      end

      it "when doc is not found" do
        post 'api/docs/favourite.json', { doc_id: "#{@doc.id.to_s}11", token: @user.token, type: "unfavourite", company_id: @company.id}
        
        expect(json["result"]).to eql(nil)
        expect(json["error"]["message"]).to eql(I18n.t("document.not_found"))
        expect(json["error"]["error_code"]).to eq(ERROR_CODES[:item_not_found])

        @user.reload
        expect(@user.favourite_document_ids.include?(@doc.id)).to eq(true)
      end
    end
  end

  ##
  # Mark a doc as read
  # /docs/mark_as_read.json
  # POST
  # @params: 
  #   doc_id
  # @response:  
  #   {result: true}
  describe "POST /docs/mark_as_read.json" do
    context "success" do
      before(:each) do
        User.destroy_all
        Document.destroy_all
        Version.destroy_all
        Delayed::Job.destroy_all

        @user = create :user, company_ids: [@company.id]
        @doc = create :document, company_id: @company.id, category_id: @category.id
        version = create :version, document_id: @doc.id
      end

      it "when doc isn't expiried" do
        post 'api/docs/mark_as_read.json', { doc_id: @doc.id.to_s, token: @user.token, company_id: @company.id}
        
        expect(json["result"]).to eql(true)

        @user.reload
        expect(@user.read_document_ids.include?(@doc.id)).to eq(true)

        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
      end

      it "when user do this action offline and doc has been changed when user online" do
        post 'api/docs/mark_as_read.json', { doc_id: @doc.id.to_s, token: @user.token, company_id: @company.id}

        post 'api/docs/mark_as_read.json', { doc_id: @doc.id.to_s, token: @user.token, company_id: @company.id, action_time: (Time.now - 1.day).utc.to_s}
        
        expect(json["result"]).to eql(true)
        expect(json["result_code"]).to eql(SUCCESS_CODES[:rejected])
        expect(json["is_unread"]).to eq(!@user.reload.read_doc?(@doc))
      end
    end

    context "errors" do
      before(:each) do
        User.destroy_all
        Document.destroy_all
        Version.destroy_all
        Delayed::Job.destroy_all

        @user = create :user, company_ids: [@company.id]
        @doc = create :document, company_id: @company.id, category_id: @category.id
        version = create :version, document_id: @doc.id
      end

      it "when doc is expiried" do
        @doc.update_attribute(:expiry, (Time.now - 1.day).utc)
        post 'api/docs/mark_as_read.json', { doc_id: @doc.id.to_s, token: @user.token, company_id: @company.id}
        
        expect(json["result"]).to eql(nil)
        expect(json["error"]["message"]).to eql(I18n.t("document.is_expiried"))
        expect(json["error"]["error_code"]).to eq(ERROR_CODES[:refresh_data])

        @user.reload
        expect(@user.read_document_ids.include?(@doc.id)).to eq(false)
      end

      it "when doc is private" do
        @user1 = create :user, token: "fdsfdsf", company_ids: [@company.id]
        @doc.update_attributes({is_private: true, private_for_id: @user1.id})

        post 'api/docs/mark_as_read.json', { doc_id: @doc.id.to_s, token: @user.token, company_id: @company.id}
        
        expect(json["result"]).to eql(nil)
        expect(json["error"]["message"]).to eql(I18n.t("document.is_private"))
        expect(json["error"]["error_code"]).to eq(ERROR_CODES[:refresh_data])

        @user.reload
        expect(@user.favourite_document_ids.include?(@doc.id)).to eq(false)
      end

      it "when doc is not found" do
        post 'api/docs/mark_as_read.json', { doc_id: "#{@doc.id.to_s}11", token: @user.token, company_id: @company.id}
        
        expect(json["result"]).to eql(nil)
        expect(json["error"]["message"]).to eql(I18n.t("document.not_found"))
        expect(json["error"]["error_code"]).to eq(ERROR_CODES[:item_not_found])

        @user.reload
        expect(@user.read_document_ids.include?(@doc.id)).to eq(false)
      end
    end
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
    context "success" do
      before(:each) do
        User.destroy_all
        Document.destroy_all
        Version.destroy_all
        Delayed::Job.destroy_all

        @user = create :user, company_ids: [@company.id]
        @doc = create :document, company_id: @company.id, category_id: @category.id
        version = create :version, document_id: @doc.id
      end

      it "when doc isn't expiried" do
        post 'api/docs/mark_all_as_read.json', {token: @user.token}
        
        expect(json["result"]).to eql(true)

        @user.reload
        expect(@user.read_document_ids.include?(@doc.id)).to eq(true)

        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
      end

      it "when user has many companies, docs" do
        company1 = create :company, name: "fdasfsdfds"
        @user.company_ids << company1.id
        @user.save

        doc1 = create :document, company_id: company1.id, category_id: @category.id
        version = create :version, document_id: doc1.id

        post 'api/docs/mark_all_as_read.json', { token: @user.token}

        @user.reload
        expect(@user.read_document_ids.include?(@doc.id)).to eq(true)
        expect(@user.read_document_ids.include?(doc1.id)).to eq(true)

        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
      end
    end
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
        User.destroy_all
        Document.destroy_all
        Version.destroy_all
        Category.destroy_all

        @user = create :user, company_ids: [@company.id]
        @category = create :category, name: "Category 1", document_ids: []

        @doc = create :document, title: "Document AA", doc_id: "TT", company_id: @company.id, category_id: @category.id
        version = create :version, document_id: @doc.id

        @doc1 = create :document, title: "Document BB", doc_id: "YY", company_id: @company.id, category_id: @category.id
        version1 = create :version, document_id: @doc1.id
      end

      it "when search_term doesn't match with any documents" do
        @category.update_attribute(:document_ids, [@doc.id])

        get 'api/docs.json', {token: @user.token, search_term: "12", company_id: @company.id}
        
        expect(json["docs"].length).to eq(0)
      end

      it "when search_term match with one document" do
        @category.update_attribute(:document_ids, [@doc.id])

        get 'api/docs.json', {token: @user.token, search_term: "aa", company_id: @company.id}
        
        expect(json["docs"].length).to eq(1)

        cate_docs = json["docs"]

        expect(cate_docs[0]["uid"]).to eq(@doc.id.to_s)
        expect(cate_docs[0]["title"]).to eq(@doc.title)
        expect(cate_docs[0]["doc_file"]).to eq(@doc.current_version.doc_file)
        expect(cate_docs[0]["version"]).to eq(@doc.current_version.version)
        expect(cate_docs[0]["is_unread"]).to eq(true)

        expect(cate_docs[0]["is_favourite"]).to eq(false)
        expect(cate_docs[0]["category"]).to eq(@doc.reload.category.try(:name).to_s)

        expect(cate_docs[0]["id"]).to eq(@doc.doc_id)
        expect(cate_docs[0]["expiry"]).to eq(@doc.expiry.utc.to_s)
        expect(cate_docs[0]["created_at"]).to eq(@doc.created_at.utc.to_s)
        expect(cate_docs[0]["updated_at"]).to eq(@doc.updated_at.utc.to_s)

        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
      end

      it "when search_term match with two documents" do
        @category.update_attribute(:document_ids, [@doc.id])

        get 'api/docs.json', {token: @user.token, search_term: "docu", company_id: @company.id}
        
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

        expect(cate_docs[1]["is_favourite"]).to eq(false)
        expect(cate_docs[1]["category"]).to eq(@doc.reload.category.try(:name).to_s)
      end
    end

    context "search in doc_id" do
      before(:each) do
        User.destroy_all
        Document.destroy_all
        Version.destroy_all
        Category.destroy_all

        @user = create :user, company_ids: [@company.id]
        @category = create :category, name: "Category 1", document_ids: []

        @doc = create :document, title: "AA", doc_id: "Code EE", company_id: @company.id, category_id: @category.id
        version = create :version, document_id: @doc.id

        @doc1 = create :document, title: "BB", doc_id: "Code DD", company_id: @company.id, category_id: @category.id
        version1 = create :version, document_id: @doc1.id
      end

      it "when search_term doesn't match with any documents" do
        @category.update_attribute(:document_ids, [@doc.id])

        get 'api/docs.json', {token: @user.token, search_term: "12", company_id: @company.id}
        
        expect(json["docs"].length).to eq(0)
      end

      it "when search_term match with one document" do
        @category.update_attribute(:document_ids, [@doc.id])

        get 'api/docs.json', {token: @user.token, search_term: "ee", company_id: @company.id}
        
        expect(json["docs"].length).to eq(1)

        cate_docs = json["docs"]

        expect(cate_docs[0]["uid"]).to eq(@doc.id.to_s)
        expect(cate_docs[0]["title"]).to eq(@doc.title)
        expect(cate_docs[0]["doc_file"]).to eq(@doc.current_version.doc_file)
        expect(cate_docs[0]["version"]).to eq(@doc.current_version.version)
        expect(cate_docs[0]["is_unread"]).to eq(true)

        expect(cate_docs[0]["is_favourite"]).to eq(false)
        expect(cate_docs[0]["category"]).to eq(@doc.reload.category.try(:name).to_s)
      end

      it "when search_term match with two documents" do
        @category.update_attribute(:document_ids, [@doc.id])

        get 'api/docs.json', {token: @user.token, search_term: "cod", company_id: @company.id}
        
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

        expect(cate_docs[1]["is_favourite"]).to eq(false)
        expect(cate_docs[1]["category"]).to eq(@doc.reload.category.try(:name).to_s)
      end
    end
  end
end
