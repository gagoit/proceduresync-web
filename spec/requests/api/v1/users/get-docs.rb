require 'spec_helper'

describe "User API" do
  before(:each) do
    create_default_data({create_doc: true})
  end

  ##
  # Get Docs in a list (favourite / unread / private)
  # /user/docs.json
  # GET
  # @params: 
  #   token, filter = unread / favourite / private
  # @response:  
  #   { 
  #     docs: [ 
  #        { uid, title, doc_file, version,  is_unread } 
  #     ], 
  #     unread_number 
  #   }

  describe "GET /user/docs.json" do
    context "filter = unread" do
      before(:each) do
        @u_comp = assign_user_to_path(@user, @company, {company_path_ids: @doc.belongs_to_paths.first})
      end

      it "return empty if user don't have accountable docs" do
        @doc.belongs_to_paths = @all_paths.keys - @doc.belongs_to_paths
        @doc.save

        get 'api/user/docs.json', {token: @user.token, filter: "unread", company_id: @company.id}

        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
        expect(json["docs"].length).to eq(0)
        expect(json["unread_number"]).to eq(0)
      end

      it "return accountable docs if user hasn't read them before (case 1: one doc)" do
        get 'api/user/docs.json', {token: @user.token, filter: "unread", company_id: @company.id}

        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
        expect(json["docs"].length).to eq(1)
        expect(json["unread_number"]).to eq(1)

        new_docs = json["docs"]

        CheckReturnDocInfo.new.test(new_docs[0], @doc)

        expect(new_docs[0]["is_unread"]).to eq(true)
        expect(new_docs[0]["is_favourite"]).to eq(false)
        expect(new_docs[0]["is_private"]).to eq(false)
      end

      it "return accountable docs if user hasn't read them before (case 2: two docs)" do
        @doc1.belongs_to_paths.concat(@doc.belongs_to_paths)
        @doc1.save

        get 'api/user/docs.json', {token: @user.token, filter: "unread", company_id: @company.id}
        
        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
        expect(json["docs"].length).to eq(2)
        expect(json["unread_number"]).to eq(2)

        new_docs = json["docs"]

        CheckReturnDocInfo.new.test(new_docs[0], @doc1)

        expect(new_docs[0]["is_unread"]).to eq(true)
        expect(new_docs[0]["is_favourite"]).to eq(false)
        expect(new_docs[0]["is_private"]).to eq(false)

        CheckReturnDocInfo.new.test(new_docs[1], @doc)

        expect(new_docs[1]["is_unread"]).to eq(true)
        expect(new_docs[1]["is_favourite"]).to eq(false)
        expect(new_docs[1]["is_private"]).to eq(false)
      end

      it "return 0 accountable docs if user has read them before" do
        @doc1.belongs_to_paths.concat(@doc.belongs_to_paths)
        @doc1.save

        @user.read_document_ids = [@doc.id, @doc1.id]
        @user.save

        @user.reload

        get 'api/user/docs.json', {token: @user.token, filter: "unread", company_id: @company.id}

        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
        expect(json["docs"].length).to eq(0)
      end

      it "return 1 accountable docs if user has 2 accountable docs, and just read one before" do
        @doc1.belongs_to_paths.concat(@doc.belongs_to_paths)
        @doc1.save

        @user.read_document_ids = [@doc.id]
        @user.save

        @user.reload

        get 'api/user/docs.json', {token: @user.token, filter: "unread", company_id: @company.id}

        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
        expect(json["docs"].length).to eq(1)

        new_docs = json["docs"]

        CheckReturnDocInfo.new.test(new_docs[0], @doc1)

        expect(new_docs[0]["is_unread"]).to eq(true)
        expect(new_docs[0]["is_favourite"]).to eq(false)
        expect(new_docs[0]["is_private"]).to eq(false)
      end
    end


    context "filter = favourite" do
      before(:each) do
      end

      it "return a favourite doc (not accountable)" do
        @user.favourite_document_ids = [@doc.id]
        @user.save

        @user.reload

        get 'api/user/docs.json', {token: @user.token, filter: "favourite", company_id: @company.id}

        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
        expect(json["docs"].length).to eq(1)
        expect(json["unread_number"]).to eq(0)

        new_docs = json["docs"]

        CheckReturnDocInfo.new.test(new_docs[0], @doc)

        expect(new_docs[0]["is_unread"]).to eq(false)
        expect(new_docs[0]["is_favourite"]).to eq(true)
        expect(new_docs[0]["is_private"]).to eq(false)
      end

      it "return a favourite doc (accountable & unread)" do
        @u_comp = assign_user_to_path(@user, @company, {company_path_ids: @doc.belongs_to_paths.first})
        @user.favourite_document_ids = [@doc.id]
        @user.save
        @user.reload

        get 'api/user/docs.json', {token: @user.token, filter: "favourite", company_id: @company.id}

        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
        expect(json["docs"].length).to eq(1)
        expect(json["unread_number"]).to eq(1)

        new_docs = json["docs"]

        CheckReturnDocInfo.new.test(new_docs[0], @doc)

        expect(new_docs[0]["is_unread"]).to eq(true)
        expect(new_docs[0]["is_favourite"]).to eq(true)
        expect(new_docs[0]["is_private"]).to eq(false)
      end

      it "return a favourite doc (accountable & has read)" do
        @u_comp = assign_user_to_path(@user, @company, {company_path_ids: @doc.belongs_to_paths.first})
        @user.favourite_document_ids = [@doc.id]
        @user.read_document_ids = [@doc.id]
        @user.save

        @user.reload
        
        get 'api/user/docs.json', {token: @user.token, filter: "favourite", company_id: @company.id}

        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
        expect(json["docs"].length).to eq(1)
        expect(json["unread_number"]).to eq(0)

        new_docs = json["docs"]

        CheckReturnDocInfo.new.test(new_docs[0], @doc)

        expect(new_docs[0]["is_unread"]).to eq(false)
        expect(new_docs[0]["is_favourite"]).to eq(true)
        expect(new_docs[0]["is_private"]).to eq(false)
      end

      it "when has two favourite docs (both of them is accountable & unread)" do
        @u_comp = assign_user_to_path(@user, @company, {company_path_ids: @doc.belongs_to_paths.first})
        @doc1.belongs_to_paths.concat(@doc.belongs_to_paths)
        @doc1.save

        @user.favourite_document_ids = [@doc.id, @doc1.id]
        @user.save

        get 'api/user/docs.json', {token: @user.token, filter: "favourite", company_id: @company.id}
        
        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
        expect(json["docs"].length).to eq(2)
        expect(json["unread_number"]).to eq(2)

        new_docs = json["docs"]

        CheckReturnDocInfo.new.test(new_docs[0], @doc1)
        expect(new_docs[0]["is_unread"]).to eq(true)
        expect(new_docs[0]["is_favourite"]).to eq(true)
        expect(new_docs[0]["is_private"]).to eq(false)

        CheckReturnDocInfo.new.test(new_docs[1], @doc)
        expect(new_docs[1]["is_unread"]).to eq(true)
        expect(new_docs[1]["is_favourite"]).to eq(true)
        expect(new_docs[1]["is_private"]).to eq(false)
      end

      it "when has two favourite docs (there docs are accountable, and one of them is unread)" do
        @u_comp = assign_user_to_path(@user, @company, {company_path_ids: @doc.belongs_to_paths.first})
        @doc1.belongs_to_paths.concat(@doc.belongs_to_paths)
        @doc1.save

        @user.favourite_document_ids = [@doc.id, @doc1.id]
        @user.read_document_ids = [@doc.id]
        @user.save

        get 'api/user/docs.json', {token: @user.token, filter: "favourite", company_id: @company.id}
        
        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
        expect(json["docs"].length).to eq(2)
        expect(json["unread_number"]).to eq(1)

        new_docs = json["docs"]

        CheckReturnDocInfo.new.test(new_docs[0], @doc1)
        expect(new_docs[0]["is_unread"]).to eq(true)
        expect(new_docs[0]["is_favourite"]).to eq(true)
        expect(new_docs[0]["is_private"]).to eq(false)

        CheckReturnDocInfo.new.test(new_docs[1], @doc)
        expect(new_docs[1]["is_unread"]).to eq(false)
        expect(new_docs[1]["is_favourite"]).to eq(true)
        expect(new_docs[1]["is_private"]).to eq(false)
      end

      it "return empty when has no favourite doc" do
        @user.favourite_document_ids = []
        @user.save

        @user.reload

        get 'api/user/docs.json', {token: @user.token, filter: "favourite", company_id: @company.id}

        expect(json["docs"].length).to eq(0)
      end
    end


    context "filter = private" do
      before(:each) do
      end

      it "return a private doc with unread always be 0" do
        @doc.update_attributes({is_private: true, private_for_id: @user.id})
        @user.reload

        get 'api/user/docs.json', {token: @user.token, filter: "private", company_id: @company.id}

        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
        expect(json["docs"].length).to eq(1)
        expect(json["unread_number"]).to eq(0)

        new_docs = json["docs"]

        CheckReturnDocInfo.new.test(new_docs[0], @doc)

        expect(new_docs[0]["is_unread"]).to eq(false)
        expect(new_docs[0]["is_favourite"]).to eq(false)
        expect(new_docs[0]["is_private"]).to eq(true)
      end

      it "return empty when has no private doc" do
        @doc.update_attributes({is_private: false, private_for_id: nil})
        @user.reload

        get 'api/user/docs.json', {token: @user.token, filter: "private", company_id: @company.id}

        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
        expect(json["docs"].length).to eq(0)
        expect(json["unread_number"]).to eq(0)
      end
    end
  end
end
