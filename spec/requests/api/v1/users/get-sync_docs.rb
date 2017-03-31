require 'spec_helper'

describe "User API" do
  before(:each) do
    create_default_data({create_doc: true})
  end

  # Sync docs for a user
  # /user/sync_docs.json
  # GET
  # @params: 
  #   { token, mark_as_read }
  # @response: 
  #   {
  #     docs: [
  #       { uid, title, doc_file, version }
  #     ],
  #     last_timestamp:
  #   }
  describe "GET /user/sync_docs.json" do
    context "when has accountable doc(s)" do
      before(:each) do
        @u_comp = assign_user_to_path(@user, @company, {company_path_ids: @doc.belongs_to_paths.first})
      end

      it "return one doc info (case 1: has only one accountable doc)" do
        get 'api/user/sync_docs.json', {token: @user.token, company_id: @company.id.to_s}
        
        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
        expect(json["docs"].length).to eq(1)

        new_docs = json["docs"]
        @user.reload

        CheckReturnDocInfo.new.test(new_docs[0], @doc)

        expect(new_docs[0]["is_favourite"]).to eq(false)
        expect(new_docs[0]["is_private"]).to eq(false)

        expect(@user.read_document_ids.include?(@doc.id)).to eq(false)
      end

      it "return two docs info (case 2: has two accountable docs)" do
        @doc1.belongs_to_paths << @u_comp.company_path_ids
        @doc1.save

        get 'api/user/sync_docs.json', {token: @user.token, company_id: @company.id}
        
        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
        expect(json["docs"].length).to eq(2)

        new_docs = json["docs"]
        @user.reload

        CheckReturnDocInfo.new.test(new_docs[0], @doc1)

        expect(new_docs[0]["is_favourite"]).to eq(false)
        expect(new_docs[0]["is_private"]).to eq(false)

        CheckReturnDocInfo.new.test(new_docs[1], @doc)

        expect(new_docs[1]["is_favourite"]).to eq(false)
        expect(new_docs[1]["is_private"]).to eq(false)

        expect(@user.read_document_ids.include?(@doc.id)).to eq(false)
        expect(@user.read_document_ids.include?(@doc1.id)).to eq(false)
      end

      it "return two docs info and read doc if user mark all as read (case 2: has two accountable docs)" do
        @doc1.belongs_to_paths << @u_comp.company_path_ids
        @doc1.save

        get 'api/user/sync_docs.json', {token: @user.token, mark_as_read: true, company_id: @company.id}
        
        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
        expect(json["docs"].length).to eq(2)

        new_docs = json["docs"]
        @user.reload

        CheckReturnDocInfo.new.test(new_docs[0], @doc1)

        expect(new_docs[0]["is_favourite"]).to eq(false)
        expect(new_docs[0]["is_private"]).to eq(false)

        CheckReturnDocInfo.new.test(new_docs[1], @doc)

        expect(new_docs[1]["is_favourite"]).to eq(false)
        expect(new_docs[1]["is_private"]).to eq(false)

        expect(@user.read_document_ids.include?(@doc.id)).to eq(true)
        expect(@user.read_document_ids.include?(@doc1.id)).to eq(true)
      end

      it "return one doc info when has two docs, but one is new doc (not sync)" do
        UserService.update_user_documents({document: @doc, company: @company})

        sleep 5
        after_timestamp = Time.now.utc.to_s
        @doc1.belongs_to_paths << @u_comp.company_path_ids
        @doc1.save

        UserService.update_user_documents({document: @doc1, company: @company})

        get 'api/user/sync_docs.json', {token: @user.token, mark_as_read: false, after_timestamp: after_timestamp, company_id: @company.id}
        
        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
        expect(json["docs"].length).to eq(1)

        new_docs = json["docs"]
        @user.reload

        CheckReturnDocInfo.new.test(new_docs[0], @doc1)

        expect(new_docs[0]["is_favourite"]).to eq(false)
        expect(new_docs[0]["is_private"]).to eq(false)

        expect(@user.read_document_ids.include?(@doc.id)).to eq(false)
        expect(@user.read_document_ids.include?(@doc1.id)).to eq(false)
      end

      it "return one doc info when has two docs, but one is new doc (not sync) and it is favourite" do
        UserService.update_user_documents({document: @doc, company: @company})

        sleep 5
        after_timestamp = Time.now.utc.to_s
        @doc1.belongs_to_paths << @u_comp.company_path_ids
        @doc1.save

        UserService.update_user_documents({document: @doc1, company: @company})
        @user.favour_document!(@doc1)
        @user.reload

        get 'api/user/sync_docs.json', {token: @user.token, mark_as_read: false, after_timestamp: after_timestamp, company_id: @company.id}
        
        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
        expect(json["docs"].length).to eq(1)

        new_docs = json["docs"]

        CheckReturnDocInfo.new.test(new_docs[0], @doc1)

        expect(new_docs[0]["is_favourite"]).to eq(true)
        expect(new_docs[0]["is_private"]).to eq(false)

        expect(@user.read_document_ids.include?(@doc.id)).to eq(false)
        expect(@user.read_document_ids.include?(@doc1.id)).to eq(false)
      end

      it "return empty when has two docs, but they've already synced" do
        @doc1.belongs_to_paths << @u_comp.company_path_ids
        @doc1.save

        UserService.update_user_documents({document: @doc, company: @company})
        UserService.update_user_documents({document: @doc1, company: @company})

        after_timestamp = (Time.now + 10.seconds).utc.to_s

        get 'api/user/sync_docs.json', {token: @user.token, mark_as_read: false, after_timestamp: after_timestamp, company_id: @company.id}
        
        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
        expect(json["docs"].length).to eq(0)
      end

      it "return one doc info when has two docs and one is active (synced), new one is inactive" do
        UserService.update_user_documents({document: @doc, company: @company})

        sleep 5
        after_timestamp = Time.now.utc.to_s
        @doc1.belongs_to_paths << @u_comp.company_path_ids
        @doc1.active = false
        @doc1.save

        UserService.update_user_documents({document: @doc1, company: @company})

        get 'api/user/sync_docs.json', {token: @user.token, mark_as_read: false, after_timestamp: after_timestamp, company_id: @company.id}
        
        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
        expect(json["docs"].length).to eq(1)

        new_docs = json["docs"]
        @user.reload

        CheckReturnDocInfo.new.test(new_docs[0], @doc1)
        expect(new_docs[0]["is_inactive"]).to eq(true)

        expect(@user.read_document_ids.include?(@doc.id)).to eq(false)
        expect(@user.read_document_ids.include?(@doc1.id)).to eq(false)
      end
    end


    context "when has private doc(s)" do
      before(:each) do
        @u_comp = assign_user_to_path(@user, @company, {company_path_ids: @doc.belongs_to_paths.first})
      end

      it "return two docs info when has a accountable doc & a private doc" do
        @doc1.update_attributes({is_private: true, private_for_id: @user.id, created_at: Time.now.utc})

        get 'api/user/sync_docs.json', {token: @user.token, mark_as_read: false, company_id: @company.id}
        
        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
        expect(json["docs"].length).to eq(2)

        new_docs = json["docs"]
        @user.reload

        CheckReturnDocInfo.new.test(new_docs[0], @doc1)
        expect(new_docs[0]["is_favourite"]).to eq(false)
        expect(new_docs[0]["is_private"]).to eq(true)

        CheckReturnDocInfo.new.test(new_docs[1], @doc)
        expect(new_docs[1]["is_favourite"]).to eq(false)
        expect(new_docs[1]["is_private"]).to eq(false)

        expect(@user.read_document_ids.include?(@doc.id)).to eq(false)
        expect(@user.read_document_ids.include?(@doc1.id)).to eq(true) #because it's private -> read
      end

      it "return empty when has two docs that are private for this other user" do
        user1, u1_comp = create_user(@company, {paths: {company_path_ids: @u_comp.company_path_ids}})

        @doc.update_attributes({is_private: true, private_for_id: user1.id})
        @doc1.update_attributes({is_private: true, private_for_id: user1.id})

        get 'api/user/sync_docs.json', {token: @user.token, mark_as_read: false, company_id: @company.id}
        
        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
        expect(json["docs"].length).to eq(0)
      end
    end


    context "when has public documents in user's section" do
      before(:each) do
        @u_comp = assign_user_to_path(@user, @company, {company_path_ids: @doc.belongs_to_paths.first})
      end

      it "return one doc info when has one public documents in user's section" do
        get 'api/user/sync_docs.json', {token: @user.token, mark_as_read: false, company_id: @company.id}
        
        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
        expect(json["docs"].length).to eq(1)

        new_docs = json["docs"]
        @user.reload

        CheckReturnDocInfo.new.test(new_docs[0], @doc)
        expect(new_docs[0]["is_favourite"]).to eq(false)
        expect(new_docs[0]["is_private"]).to eq(false)

        expect(@user.read_document_ids.include?(@doc.id)).to eq(false)
      end
    end


    context "when has non-accountable documents that are not restricted and are favourite by user" do
      before(:each) do
        other_path = (@all_paths.keys - @doc.belongs_to_paths).first.to_s
        @u_comp = assign_user_to_path(@user, @company, {company_path_ids: other_path})
      end

      it "return one favourite doc info when has two non-accountable docs but user has favourite one doc" do
        @user.favour_document!(@doc)
        @user.reload

        get 'api/user/sync_docs.json', {token: @user.token, mark_as_read: false, company_id: @company.id}
        
        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
        expect(json["docs"].length).to eq(1)

        new_docs = json["docs"]

        CheckReturnDocInfo.new.test(new_docs[0], @doc)
        expect(new_docs[0]["is_favourite"]).to eq(true)
        expect(new_docs[0]["is_private"]).to eq(false)

        expect(@user.read_document_ids.include?(@doc.id)).to eq(false)
      end

      it "return empty when has two non-accountable & restricted docs but user has favourite one doc" do
        @user.favour_document!(@doc)

        @doc.restricted = true
        @doc.save

        @doc1.restricted = true
        @doc1.save

        get 'api/user/sync_docs.json', {token: @user.token, mark_as_read: false, company_id: @company.id}
        
        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
        expect(json["docs"].length).to eq(0)
      end
    end


    context "when has updated doc(s)" do
      before(:each) do
        @u_comp = assign_user_to_path(@user, @company, {company_path_ids: @doc.belongs_to_paths.first})
      end

      it "return one doc info when has two synced docs & has a new updated doc (update version name)" do
        user1, u1_comp = create_user(@company, {paths: {company_path_ids: @u_comp.company_path_ids}})
        @doc1.update_attributes({is_private: true, private_for_id: user1.id})

        UserService.update_user_documents({document: @doc, company: @company})
        UserService.update_user_documents({document: @doc1, company: @company})

        sleep 5
        after_timestamp = Time.now.utc.to_s
        sleep 1

        @version.version = "new version"
        @version.save
        @doc.curr_version = @version.version
        @doc.save
        UserService.update_user_documents({document: @doc, company: @company, new_version: true})

        get 'api/user/sync_docs.json', {token: @user.token, mark_as_read: false, after_timestamp: after_timestamp, company_id: @company.id}

        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
        expect(json["docs"].length).to eq(1)

        new_docs = json["docs"]
        @user.reload
        @doc.reload

        CheckReturnDocInfo.new.test(new_docs[0], @doc)

        expect(new_docs[0]["is_favourite"]).to eq(false)
        expect(new_docs[0]["is_private"]).to eq(false)
      end

      it "return one doc info when has a synced doc & add new version to a doc" do
        UserService.update_user_documents({document: @doc, company: @company})

        sleep 2
        after_timestamp = Time.now.utc.to_s

        version1 = create :version, document_id: @doc.id, box_status: "done", box_file_size: 100
        @doc.curr_version = version1.version
        @doc.save
        UserService.update_user_documents({document: @doc, company: @company, new_version: true})

        get 'api/user/sync_docs.json', {token: @user.token, mark_as_read: false, after_timestamp: after_timestamp, company_id: @company.id}

        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
        expect(json["docs"].length).to eq(1)

        new_docs = json["docs"]
        @user.reload
        @doc.reload

        CheckReturnDocInfo.new.test(new_docs[0], @doc)

        expect(new_docs[0]["is_favourite"]).to eq(false)
        expect(new_docs[0]["is_private"]).to eq(false)
      end

      it "return one doc info when has a synced doc & it has updated (update category name)" do
        UserService.update_user_documents({document: @doc, company: @company})

        sleep 2
        after_timestamp = Time.now.utc.to_s

        @category.name = "new name"
        @category.document_ids = [@doc.id]
        @category.save
        UserService.update_user_documents({document: @doc, company: @company})

        get 'api/user/sync_docs.json', {token: @user.token, mark_as_read: false, after_timestamp: after_timestamp, company_id: @company.id}
        
        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
        expect(json["docs"].length).to eq(1)

        new_docs = json["docs"]
        @user.reload
        @doc.reload

        CheckReturnDocInfo.new.test(new_docs[0], @doc)

        expect(new_docs[0]["is_favourite"]).to eq(false)
        expect(new_docs[0]["is_private"]).to eq(false)
      end
    end
  end
end