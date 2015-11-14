require 'spec_helper'

describe "User API" do
  before(:each) do
    Company.destroy_all
    
    @company = create :company
  end
  #Show Account  
  # /user.json  
  # GET  
  # @params: 
  #   {uid}
  # @response: 
  #   {uid, :name, :has_setup, :home_email}
  describe "Get /user.json" do
    context "works" do
      before(:each) do
        User.destroy_all
      end

      it "return user on db" do
        user = create :user, home_email: "vuongtieulong02@gmail.com", has_setup: true, company_ids: [@company.id]
        
        get 'api/user.json', {uid: user.id.to_s, token: user.token}

        user.reload
        
        expect(json["uid"]).to eql(user.id.to_s)
        expect(json["name"]).to eql(user.name)
        expect(json["has_setup"]).to eql(user.has_setup)
        expect(json["home_email"]).to eql(user.home_email)

        expect(json["token"]).to eq(user.token)

        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])

        expect(json["companies"].length).to eq(1)
      end

      it "& return error when user not found" do
        get 'api/user.json' , {uid: 1, token: ""}

        expect(json["error"]["message"]).to eql(I18n.t("user.null_or_invalid_token"))
        expect(json["error"]["error_code"]).to eql(ERROR_CODES[:invalid_value])
      end
    end
  end

  ##
  # Sign In /user/token.json POST  
  # @params:
  #    email, password 
  # @response:
  #    {uid, name, token, has_setup, company }
  # @error response:
  #    {error:{message,error_code,debugDesc:{}}}
  ##
  describe "POST /token.json" do
    context "works" do
      before(:each) do
        User.destroy_all
      end

      it "return user in db" do
        user = create :user, company_ids: [@company.id]

        user.password = "Phambadat1qazxsw2"
        user.save
        
        post 'api/user/token.json', { email: user.email, password: "Phambadat1qazxsw2" }
        
        user.reload
        expect(json["uid"]).to eql(user.id.to_s)
        expect(json["name"]).to eql(user.name)
        expect(json["has_setup"]).to eql(user.has_setup)
        expect(json["home_email"]).to eql(user.home_email)

        expect(json["companies"].length).to eql(1)

        company = json["companies"].first

        expect(company["name"]).to eql(@company.name)
        expect(company["uid"]).to eql(@company.id.to_s)
        expect(company["logo_url"]).to eql(@company.logo_iphone4_url)

        expect(json["token"]).to eq(user.token)

        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
      end

      it "& return error when user is inactive" do
        user = create :user, active: false

        user.password = "Phambadat1qazxsw2"
        user.save
        
        post 'api/user/token.json' , {email: user.email, password: "Phambadat1qazxsw2"}
        expect(json["error"]["message"]).to eql(I18n.t("user.disabled"))
        expect(json["error"]["error_code"]).to eql(ERROR_CODES[:user_is_inactive])
      end

      it "& return error when user has no company" do
        user = create :user, active: true

        user.password = "Phambadat1qazxsw2"
        user.save
        
        post 'api/user/token.json' , {email: user.email, password: "Phambadat1qazxsw2"}
        expect(json["error"]["message"]).to eql(I18n.t("company.is_inactive"))
        expect(json["error"]["error_code"]).to eql(ERROR_CODES[:user_is_inactive])
      end

      it "& return error when user has just one company and it is inactive" do
        user = create :user, company_ids: [@company.id]

        user.password = "Phambadat1qazxsw2"
        user.save

        @company.active = false
        @company.save
        
        post 'api/user/token.json' , {email: user.email, password: "Phambadat1qazxsw2"}
        expect(json["error"]["message"]).to eql(I18n.t("company.is_inactive"))
        expect(json["error"]["error_code"]).to eql(ERROR_CODES[:user_is_inactive])
      end

      it "& return error when user not found" do
        user = create :user
        
        post 'api/user/token.json' , {email: "1"}
        expect(json["error"]["message"]).to eql(I18n.t("user.email_not_found"))
        expect(json["error"]["error_code"]).to eql(ERROR_CODES[:item_not_found])
      end

      it "& return error when password is wrong" do
        user = create :user

        user.password = "Phambadat1qazxsw2"
        user.save
        
        post 'api/user/token.json' , {email: user.email, password: "fdsfs"}
        expect(json["error"]["message"]).to eql(I18n.t("user.password_invalid"))
        expect(json["error"]["error_code"]).to eql(ERROR_CODES[:invalid_value])
      end

      it "When signing-in, email address can be case insensitive" do
        user = create :user, company_ids: [@company.id]

        user.password = "Phambadat1qazxsw2"
        user.save
        
        post 'api/user/token.json' , {email: user.email.upcase, password: "Phambadat1qazxsw2"}
        
        user.reload

        expect(json["uid"]).to eql(user.id.to_s)
        expect(json["name"]).to eql(user.name)
        expect(json["has_setup"]).to eql(user.has_setup)
        expect(json["home_email"]).to eql(user.home_email)

        expect(json["token"]).to eq(user.token)
      end
    end
  end


  #forgot password
  # /user/forgot_password.json
  # POST  
  # @params: 
  #   {email}
  # @response: 
  #   {result:true}
  #
  describe "POST /forgot_password.json" do
    context "works" do
      before(:each) do
        User.destroy_all
        Delayed::Job.destroy_all
      end

      it "when user is found in db" do
        user = create :user, company_ids: [@company.id]
        Delayed::Job.destroy_all
        
        post 'api/user/forgot_password.json', { email: user.email}
        
        expect(json["result"]).to eql(true)

        user.reload

        expect(user.has_setup).to eql(false)

        expect(Delayed::Job.count).to eq(1)

        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
      end

      it "return error when user is not in db" do
        user = create :user
        
        post 'api/user/forgot_password.json', { email: "sss"}
        
        expect(json["error"]["message"]).to eql(I18n.t("user.email_not_found"))
        expect(json["error"]["error_code"]).to eql(ERROR_CODES[:item_not_found])
      end
    end
  end


  #Update Account  
  # /user.json  
  # PUT  
  # @params: 
  #   {push_token, home_email, password}
  # @response: 
  #   {result: true}
  describe "PUT /user.json" do
    context "works" do
      before(:each) do
        User.destroy_all
        @user = create :user, company_ids: [@company.id]
        @user_hash = @user.attributes.except(:id)
      end

      it "when update home_email & password" do
        @user_hash[:uid] = @user.id.to_s
        @user_hash[:home_email] = "abc@gmail.com"
        @user_hash[:password] = "qwertyuiop"

        put 'api/user.json', @user_hash
        
        @user.reload

        #expect(json["result"]).to eq(true)
        expect(json["uid"]).to eql(@user.id.to_s)
        expect(json["name"]).to eql(@user.name)
        expect(json["has_setup"]).to eql(@user.has_setup)
        expect(json["home_email"]).to eql(@user.home_email)
        expect(json["token"]).to eql(@user.token)

        expect(@user.home_email).to eq(@user_hash[:home_email])
        expect(@user.valid_password?(@user_hash[:password])).to eq(true)

        expect(json["result_code"]).to eql(SUCCESS_CODES[:refresh_data])
      end

      it "when update push_token" do
        @user_hash[:uid] = @user.id.to_s
        @user_hash[:push_token] = "qwertyuiopqwertyuiop"

        put 'api/user.json', @user_hash
        
        @user.reload

        #expect(json["result"]).to eq(true)
        expect(json["uid"]).to eql(@user.id.to_s)
        expect(json["name"]).to eql(@user.name)
        expect(json["has_setup"]).to eql(@user.has_setup)
        expect(json["home_email"]).to eql(@user.home_email)

        expect(json["has_setup"]).to eql(@user.has_setup)
        expect(@user.has_setup).to eql(true)

        expect(@user.push_token).to eq(@user_hash[:push_token])
      end

      # error cases ==================
      it "& return error when user not found" do
        put 'api/user.json' , {uid: 1}
        expect(json["error"]["message"]).to eql(I18n.t('user.null_or_invalid_token'))
        expect(json["error"]["error_code"]).to eq(ERROR_CODES[:invalid_value])
      end

      it "& return error when name is missing" do
        @user_hash[:uid] = @user.id.to_s
        @user_hash["name"] = nil
        put 'api/user.json', @user_hash
        
        expect(json["error"]["message"]).to eq("Name can't be blank")
        expect(json["error"]["error_code"]).to eq(ERROR_CODES[:invalid_value])
      end
    end
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
    context "works" do
      before(:each) do
        User.destroy_all
        Document.destroy_all
        Version.destroy_all
        Category.destroy_all

        @user = create :user, company_ids: [@company.id]
        @category = create :category, company_id: @company.id

        @doc = create :document, company_id: @company.id, category_id: @category.id
        @version = create :version, document_id: @doc.id
      end

      it "when has a new doc & user don't mark all as read" do
        get 'api/user/sync_docs.json', {token: @user.token, company_id: @company.id.to_s}
        
        @user.reload

        expect(json["docs"].length).to eq(1)

        new_docs = json["docs"]

        expect(new_docs[0]["uid"]).to eq(@doc.id.to_s)
        expect(new_docs[0]["title"]).to eq(@doc.title)
        expect(new_docs[0]["doc_file"]).to eq(@doc.current_version.doc_file)
        expect(new_docs[0]["version"]).to eq(@doc.current_version.version)

        expect(new_docs[0]["is_favourite"]).to eq(false)
        expect(new_docs[0]["category"]).to eq(@doc.category.try(:name).to_s)
        expect(new_docs[0]["is_private"]).to eq(false)

        expect(@user.read_document_ids.include?(@doc.id)).to eq(false)

        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
      end

      it "when has two new docs & user don't mark all as read" do
        @doc1 = create :document, company_id: @company.id, category_id: @category.id
        version1 = create :version, document_id: @doc1.id

        get 'api/user/sync_docs.json', {token: @user.token, company_id: @company.id}
        
        @user.reload

        expect(json["docs"].length).to eq(2)

        new_docs = json["docs"]

        expect(new_docs[0]["uid"]).to eq(@doc1.id.to_s)
        expect(new_docs[0]["title"]).to eq(@doc1.title)
        expect(new_docs[0]["doc_file"]).to eq(@doc1.current_version.doc_file)
        expect(new_docs[0]["version"]).to eq(@doc1.current_version.version)

        expect(new_docs[0]["is_favourite"]).to eq(false)
        expect(new_docs[0]["category"]).to eq(@doc1.category.try(:name).to_s)
        expect(new_docs[0]["is_private"]).to eq(false)

        expect(new_docs[1]["uid"]).to eq(@doc.id.to_s)
        expect(new_docs[1]["title"]).to eq(@doc.title)
        expect(new_docs[1]["doc_file"]).to eq(@doc.current_version.doc_file)
        expect(new_docs[1]["version"]).to eq(@doc.current_version.version)

        expect(new_docs[1]["is_favourite"]).to eq(false)
        expect(new_docs[1]["category"]).to eq(@doc.category.try(:name).to_s)
        expect(new_docs[1]["is_private"]).to eq(false)

        expect(@user.read_document_ids.include?(@doc.id)).to eq(false)
        expect(@user.read_document_ids.include?(@doc1.id)).to eq(false)

        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
      end

      it "when has two new docs & user mark all as read" do
        @doc1 = create :document, company_id: @company.id, category_id: @category.id

        version1 = create :version, document_id: @doc1.id

        get 'api/user/sync_docs.json', {token: @user.token, mark_as_read: true, company_id: @company.id}
        
        @user.reload

        expect(json["docs"].length).to eq(2)

        new_docs = json["docs"]

        expect(new_docs[0]["uid"]).to eq(@doc1.id.to_s)
        expect(new_docs[0]["title"]).to eq(@doc1.title)
        expect(new_docs[0]["doc_file"]).to eq(@doc1.current_version.doc_file)
        expect(new_docs[0]["version"]).to eq(@doc1.current_version.version)

        expect(new_docs[0]["is_favourite"]).to eq(false)
        expect(new_docs[0]["category"]).to eq(@doc1.category.try(:name).to_s)
        expect(new_docs[0]["is_private"]).to eq(false)

        expect(new_docs[1]["uid"]).to eq(@doc.id.to_s)
        expect(new_docs[1]["title"]).to eq(@doc.title)
        expect(new_docs[1]["doc_file"]).to eq(@doc.current_version.doc_file)
        expect(new_docs[1]["version"]).to eq(@doc.current_version.version)

        expect(new_docs[1]["is_favourite"]).to eq(false)
        expect(new_docs[1]["category"]).to eq(@doc.category.try(:name).to_s)
        expect(new_docs[1]["is_private"]).to eq(false)

        expect(@user.read_document_ids.include?(@doc.id)).to eq(true)
        expect(@user.read_document_ids.include?(@doc1.id)).to eq(true)
      end


      it "when has two docs & has a new doc (not sync)" do
        sleep 5

        after_timestamp = Time.now.utc.to_s
        @doc1 = create :document, company_id: @company.id, category_id: @category.id

        version1 = create :version, document_id: @doc1.id

        get 'api/user/sync_docs.json', {token: @user.token, mark_as_read: false, after_timestamp: after_timestamp, company_id: @company.id}
        
        @user.reload

        expect(json["docs"].length).to eq(1)

        new_docs = json["docs"]

        expect(new_docs[0]["uid"]).to eq(@doc1.id.to_s)
        expect(new_docs[0]["title"]).to eq(@doc1.title)
        expect(new_docs[0]["doc_file"]).to eq(@doc1.current_version.doc_file)
        expect(new_docs[0]["version"]).to eq(@doc1.current_version.version)

        expect(new_docs[0]["is_favourite"]).to eq(false)
        expect(new_docs[0]["category"]).to eq(@doc1.category.try(:name).to_s)
        expect(new_docs[0]["is_private"]).to eq(false)

        expect(@user.read_document_ids.include?(@doc.id)).to eq(false)
        expect(@user.read_document_ids.include?(@doc1.id)).to eq(false)
      end

      it "when has two docs & has a new doc (not sync) and it is favourites" do
        sleep 5
        after_timestamp = Time.now.utc.to_s
        @doc1 = create :document, company_id: @company.id, category_id: @category.id
        version1 = create :version, document_id: @doc1.id

        @user.update_attribute(:favourite_document_ids, [@doc1.id])

        get 'api/user/sync_docs.json', {token: @user.token, mark_as_read: false, after_timestamp: after_timestamp, company_id: @company.id}
        
        @user.reload

        expect(json["docs"].length).to eq(1)

        new_docs = json["docs"]

        expect(new_docs[0]["uid"]).to eq(@doc1.id.to_s)
        expect(new_docs[0]["title"]).to eq(@doc1.title)
        expect(new_docs[0]["doc_file"]).to eq(@doc1.current_version.doc_file)
        expect(new_docs[0]["version"]).to eq(@doc1.current_version.version)

        expect(new_docs[0]["is_favourite"]).to eq(true)
        expect(new_docs[0]["category"]).to eq(@doc1.category.try(:name).to_s)
        expect(new_docs[0]["is_private"]).to eq(false)

        expect(@user.read_document_ids.include?(@doc.id)).to eq(false)
        expect(@user.read_document_ids.include?(@doc1.id)).to eq(false)
      end

      it "when has two docs & has no new doc" do
        @doc1 = create :document, company_id: @company.id, category_id: @category.id

        version1 = create :version, document_id: @doc1.id

        after_timestamp = (Time.now + 10.seconds).utc.to_s

        get 'api/user/sync_docs.json', {token: @user.token, mark_as_read: false, after_timestamp: after_timestamp, company_id: @company.id}
        
        @user.reload

        expect(json["docs"].length).to eq(0)
      end

      it "when has two docs & has a new doc (not sync) and it's inactive" do
        sleep 5

        after_timestamp = Time.now.utc.to_s
        @doc1 = create :document, company_id: @company.id, expiry: (Time.now - 10.seconds).utc, category_id: @category.id

        version1 = create :version, document_id: @doc1.id

        get 'api/user/sync_docs.json', {token: @user.token, mark_as_read: false, after_timestamp: after_timestamp, company_id: @company.id}
        
        @user.reload

        expect(json["docs"].length).to eq(1)

        new_docs = json["docs"]

        expect(new_docs[0]["uid"]).to eq(@doc1.id.to_s)
        expect(new_docs[0]["title"]).to eq(@doc1.title)
        expect(new_docs[0]["doc_file"]).to eq(@doc1.current_version.doc_file)
        expect(new_docs[0]["version"]).to eq(@doc1.current_version.version)
        expect(new_docs[0]["is_inactive"]).to eq(true)

        expect(@user.read_document_ids.include?(@doc.id)).to eq(false)
        expect(@user.read_document_ids.include?(@doc1.id)).to eq(false)
      end

      it "when has two docs & has a new doc (not sync) and it is private for this user" do
        sleep 5

        after_timestamp = Time.now.utc.to_s
        @doc1 = create :document, company_id: @company.id, category_id: @category.id
        version1 = create :version, document_id: @doc1.id

        @doc1.update_attributes({is_private: true, private_for_id: @user.id})

        get 'api/user/sync_docs.json', {token: @user.token, mark_as_read: false, after_timestamp: after_timestamp, company_id: @company.id}
        
        @user.reload

        expect(json["docs"].length).to eq(1)

        new_docs = json["docs"]

        expect(new_docs[0]["uid"]).to eq(@doc1.id.to_s)
        expect(new_docs[0]["title"]).to eq(@doc1.title)
        expect(new_docs[0]["doc_file"]).to eq(@doc1.current_version.doc_file)
        expect(new_docs[0]["version"]).to eq(@doc1.current_version.version)

        expect(new_docs[0]["is_favourite"]).to eq(false)
        expect(new_docs[0]["category"]).to eq(@doc1.category.try(:name).to_s)
        expect(new_docs[0]["is_private"]).to eq(true)

        expect(new_docs[0]["id"]).to eq(@doc1.doc_id)
        expect(new_docs[0]["expiry"]).to eq(@doc1.expiry.utc.to_s)
        expect(new_docs[0]["created_at"]).to eq(@doc1.created_at.utc.to_s)
        expect(new_docs[0]["updated_at"]).to eq(@doc1.updated_at.utc.to_s)

        expect(@user.read_document_ids.include?(@doc.id)).to eq(false)
        expect(@user.read_document_ids.include?(@doc1.id)).to eq(false)
      end

      it "when has two docs & has a new doc (not sync) and it is private for this other user" do
        sleep 5

        after_timestamp = Time.now.utc.to_s
        @doc1 = create :document, company_id: @company.id, category_id: @category.id
        version1 = create :version, document_id: @doc1.id

        user1 = create :user, token: "fda"

        @doc1.update_attributes({is_private: true, private_for_id: user1.id})

        get 'api/user/sync_docs.json', {token: @user.token, mark_as_read: false, after_timestamp: after_timestamp, company_id: @company.id}
        
        @user.reload

        expect(json["docs"].length).to eq(0)
      end

      it "when has two synced docs & has a new updated doc (update version name) and it is private for this other user" do
        @doc1 = create :document, company_id: @company.id, category_id: @category.id
        version1 = create :version, document_id: @doc1.id

        user1 = create :user, token: "fda"

        @doc1.update_attributes({is_private: true, private_for_id: user1.id})

        sleep 5

        after_timestamp = Time.now.utc.to_s

        @version.version = "new version"
        @version.save

        get 'api/user/sync_docs.json', {token: @user.token, mark_as_read: false, after_timestamp: after_timestamp, company_id: @company.id}
        
        @user.reload
        @doc.reload

        expect(json["docs"].length).to eq(1)

        new_docs = json["docs"]

        expect(new_docs[0]["uid"]).to eq(@doc.id.to_s)
        expect(new_docs[0]["title"]).to eq(@doc.title)
        expect(new_docs[0]["doc_file"]).to eq(@doc.current_version.doc_file)
        expect(new_docs[0]["version"]).to eq(@doc.current_version.version)

        expect(new_docs[0]["is_favourite"]).to eq(false)
        expect(new_docs[0]["category"]).to eq(@doc.category.try(:name).to_s)
        expect(new_docs[0]["is_private"]).to eq(false)

        expect(new_docs[0]["id"]).to eq(@doc.doc_id)
        expect(new_docs[0]["expiry"]).to eq(@doc.expiry.utc.to_s)
        expect(new_docs[0]["created_at"]).to eq(@doc.created_at.utc.to_s)
        expect(new_docs[0]["updated_at"]).to eq(@doc.updated_at.utc.to_s)
      end

      it "when has a synced doc & it has updated (add new version)" do
        sleep 2
        after_timestamp = Time.now.utc.to_s

        version1 = create :version, document_id: @doc.id

        get 'api/user/sync_docs.json', {token: @user.token, mark_as_read: false, after_timestamp: after_timestamp, company_id: @company.id}
        
        @user.reload
        @doc.reload

        expect(json["docs"].length).to eq(1)

        new_docs = json["docs"]

        expect(new_docs[0]["uid"]).to eq(@doc.id.to_s)
        expect(new_docs[0]["title"]).to eq(@doc.title)
        expect(new_docs[0]["doc_file"]).to eq(@doc.current_version.doc_file)
        expect(new_docs[0]["version"]).to eq(@doc.current_version.version)

        expect(new_docs[0]["is_favourite"]).to eq(false)
        expect(new_docs[0]["category"]).to eq(@doc.category.try(:name).to_s)
        expect(new_docs[0]["is_private"]).to eq(false)

        expect(new_docs[0]["id"]).to eq(@doc.doc_id)
        expect(new_docs[0]["expiry"]).to eq(@doc.expiry.utc.to_s)
        expect(new_docs[0]["created_at"]).to eq(@doc.created_at.utc.to_s)
        expect(new_docs[0]["updated_at"]).to eq(@doc.updated_at.utc.to_s)
      end

      it "when has a synced doc & it has updated (update category name)" do
        after_timestamp = Time.now.utc.to_s
        sleep 2

        @category.name = "new name"
        @category.document_ids = [@doc.id]
        @category.save

        get 'api/user/sync_docs.json', {token: @user.token, mark_as_read: false, after_timestamp: after_timestamp, company_id: @company.id}
        
        @user.reload
        @doc.reload

        expect(json["docs"].length).to eq(1)

        new_docs = json["docs"]

        expect(new_docs[0]["uid"]).to eq(@doc.id.to_s)
        expect(new_docs[0]["title"]).to eq(@doc.title)
        expect(new_docs[0]["doc_file"]).to eq(@doc.current_version.doc_file)
        expect(new_docs[0]["version"]).to eq(@doc.current_version.version)

        expect(new_docs[0]["is_favourite"]).to eq(false)
        expect(new_docs[0]["category"]).to eq(@doc.category.try(:name).to_s)
        expect(new_docs[0]["is_private"]).to eq(false)

        expect(new_docs[0]["id"]).to eq(@doc.doc_id)
        expect(new_docs[0]["expiry"]).to eq(@doc.expiry.utc.to_s)
        expect(new_docs[0]["created_at"]).to eq(@doc.created_at.utc.to_s)
        expect(new_docs[0]["updated_at"]).to eq(@doc.updated_at.utc.to_s)
      end
    end
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
        User.destroy_all
        Document.destroy_all
        Category.destroy_all

        @user = create :user, company_ids: [@company.id]
        @category = create :category, company_id: @company.id

        @doc = create :document, company_id: @company.id, category_id: @category.id
        version = create :version, document_id: @doc.id
      end

      it "when has a unread doc" do
        get 'api/user/docs.json', {token: @user.token, filter: "unread", company_id: @company.id}

        expect(json["docs"].length).to eq(1)
        expect(json["unread_number"]).to eq(1)

        new_docs = json["docs"]

        expect(new_docs[0]["uid"]).to eq(@doc.id.to_s)
        expect(new_docs[0]["title"]).to eq(@doc.title)
        expect(new_docs[0]["doc_file"]).to eq(@doc.current_version.doc_file)
        expect(new_docs[0]["version"]).to eq(@doc.current_version.version)

        expect(new_docs[0]["is_unread"]).to eq(true)

        expect(new_docs[0]["is_favourite"]).to eq(false)
        expect(new_docs[0]["category"]).to eq(@doc.category.try(:name).to_s)
        expect(new_docs[0]["is_private"]).to eq(false)

        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
      end

      it "when has two unread docs" do
        @doc1 = create :document, company_id: @company.id, category_id: @category.id
        version1 = create :version, document_id: @doc1.id

        get 'api/user/docs.json', {token: @user.token, filter: "unread", company_id: @company.id}
        
        expect(json["docs"].length).to eq(2)
        expect(json["unread_number"]).to eq(2)

        new_docs = json["docs"]

        expect(new_docs[0]["uid"]).to eq(@doc1.id.to_s)
        expect(new_docs[0]["title"]).to eq(@doc1.title)
        expect(new_docs[0]["doc_file"]).to eq(@doc1.current_version.doc_file)
        expect(new_docs[0]["version"]).to eq(@doc1.current_version.version)
        expect(new_docs[0]["is_unread"]).to eq(true)

        expect(new_docs[0]["is_favourite"]).to eq(false)
        expect(new_docs[0]["category"]).to eq(@category.name)

        expect(new_docs[1]["uid"]).to eq(@doc.id.to_s)
        expect(new_docs[1]["title"]).to eq(@doc.title)
        expect(new_docs[1]["doc_file"]).to eq(@doc.current_version.doc_file)
        expect(new_docs[1]["version"]).to eq(@doc.current_version.version)
        expect(new_docs[1]["is_unread"]).to eq(true)

        expect(new_docs[1]["is_favourite"]).to eq(false)
        expect(new_docs[1]["category"]).to eq(@doc.category.try(:name).to_s)
        expect(new_docs[1]["is_private"]).to eq(false)
      end

      it "when has two docs & has no unread doc" do
        @doc1 = create :document, company_id: @company.id, category_id: @category.id
        version1 = create :version, document_id: @doc1.id
        
        @user.read_document_ids = [@doc.id, @doc1.id]
        @user.save

        @user.reload

        get 'api/user/docs.json', {token: @user.token, filter: "unread", company_id: @company.id}

        expect(json["docs"].length).to eq(0)
      end

      it "when has two docs & has a unread doc" do
        @doc1 = create :document, company_id: @company.id, category_id: @category.id
        version1 = create :version, document_id: @doc1.id

        @user.read_document_ids = [@doc.id]
        @user.save

        @user.reload

        get 'api/user/docs.json', {token: @user.token, filter: "unread", company_id: @company.id}

        expect(json["docs"].length).to eq(1)

        new_docs = json["docs"]

        expect(new_docs[0]["uid"]).to eq(@doc1.id.to_s)
        expect(new_docs[0]["title"]).to eq(@doc1.title)
        expect(new_docs[0]["doc_file"]).to eq(@doc1.current_version.doc_file)
        expect(new_docs[0]["version"]).to eq(@doc1.current_version.version)
        expect(new_docs[0]["is_unread"]).to eq(true)

        expect(new_docs[0]["is_favourite"]).to eq(false)
        expect(new_docs[0]["category"]).to eq(@doc1.category.try(:name).to_s)
        expect(new_docs[0]["is_private"]).to eq(false)
      end
    end


    context "filter = favourite" do
      before(:each) do
        User.destroy_all
        Document.destroy_all
        Category.destroy_all

        @user = create :user, company_ids: [@company.id]
        @category = create :category, company_id: @company.id

        @doc = create :document, company_id: @company.id, category_id: @category.id
        version = create :version, document_id: @doc.id
      end

      it "when has a favourite doc (and also unread)" do
        @user.favourite_document_ids = [@doc.id]
        @user.save

        @user.reload

        get 'api/user/docs.json', {token: @user.token, filter: "favourite", company_id: @company.id}

        expect(json["docs"].length).to eq(1)
        expect(json["unread_number"]).to eq(1)

        new_docs = json["docs"]

        expect(new_docs[0]["uid"]).to eq(@doc.id.to_s)
        expect(new_docs[0]["title"]).to eq(@doc.title)
        expect(new_docs[0]["doc_file"]).to eq(@doc.current_version.doc_file)
        expect(new_docs[0]["version"]).to eq(@doc.current_version.version)

        expect(new_docs[0]["is_unread"]).to eq(true)

        expect(new_docs[0]["is_favourite"]).to eq(true)
        expect(new_docs[0]["category"]).to eq(@doc.category.try(:name).to_s)
        expect(new_docs[0]["is_private"]).to eq(false)

        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
      end

      it "when has a favourite doc (but this doc is read)" do
        @user.favourite_document_ids = [@doc.id]
        @user.read_document_ids = [@doc.id]
        @user.save

        @user.reload
        
        get 'api/user/docs.json', {token: @user.token, filter: "favourite", company_id: @company.id}

        expect(json["docs"].length).to eq(1)
        expect(json["unread_number"]).to eq(0)

        new_docs = json["docs"]

        expect(new_docs[0]["uid"]).to eq(@doc.id.to_s)
        expect(new_docs[0]["title"]).to eq(@doc.title)
        expect(new_docs[0]["doc_file"]).to eq(@doc.current_version.doc_file)
        expect(new_docs[0]["version"]).to eq(@doc.current_version.version)

        expect(new_docs[0]["is_unread"]).to eq(false)

        expect(new_docs[0]["is_favourite"]).to eq(true)
        expect(new_docs[0]["category"]).to eq(@doc.category.try(:name).to_s)
        expect(new_docs[0]["is_private"]).to eq(false)
      end

      it "when has two favourite docs (both of them is unread)" do
        @doc1 = create :document, company_id: @company.id, category_id: @category.id
        version1 = create :version, document_id: @doc1.id

        @user.favourite_document_ids = [@doc.id, @doc1.id]
        @user.save

        get 'api/user/docs.json', {token: @user.token, filter: "favourite", company_id: @company.id}
        
        expect(json["docs"].length).to eq(2)
        expect(json["unread_number"]).to eq(2)

        new_docs = json["docs"]

        expect(new_docs[0]["uid"]).to eq(@doc1.id.to_s)
        expect(new_docs[0]["title"]).to eq(@doc1.title)
        expect(new_docs[0]["doc_file"]).to eq(@doc1.current_version.doc_file)
        expect(new_docs[0]["version"]).to eq(@doc1.current_version.version)
        expect(new_docs[0]["is_unread"]).to eq(true)

        expect(new_docs[0]["is_favourite"]).to eq(true)
        expect(new_docs[0]["category"]).to eq(@doc1.category.try(:name).to_s)
        expect(new_docs[0]["is_private"]).to eq(false)

        expect(new_docs[1]["uid"]).to eq(@doc.id.to_s)
        expect(new_docs[1]["title"]).to eq(@doc.title)
        expect(new_docs[1]["doc_file"]).to eq(@doc.current_version.doc_file)
        expect(new_docs[1]["version"]).to eq(@doc.current_version.version)
        expect(new_docs[1]["is_unread"]).to eq(true)

        expect(new_docs[1]["is_favourite"]).to eq(true)
        expect(new_docs[1]["category"]).to eq(@doc.category.try(:name).to_s)
        expect(new_docs[1]["is_private"]).to eq(false)
      end

      it "when has two favourite docs (one of them is unread)" do
        @doc1 = create :document, company_id: @company.id, category_id: @category.id
        version1 = create :version, document_id: @doc1.id

        @user.favourite_document_ids = [@doc.id, @doc1.id]
        @user.read_document_ids = [@doc.id]
        @user.save

        get 'api/user/docs.json', {token: @user.token, filter: "favourite", company_id: @company.id}
        
        expect(json["docs"].length).to eq(2)
        expect(json["unread_number"]).to eq(1)

        new_docs = json["docs"]

        expect(new_docs[0]["uid"]).to eq(@doc1.id.to_s)
        expect(new_docs[0]["title"]).to eq(@doc1.title)
        expect(new_docs[0]["doc_file"]).to eq(@doc1.current_version.doc_file)
        expect(new_docs[0]["version"]).to eq(@doc1.current_version.version)
        expect(new_docs[0]["is_unread"]).to eq(true)

        expect(new_docs[0]["is_favourite"]).to eq(true)
        expect(new_docs[0]["category"]).to eq(@doc1.category.try(:name).to_s)
        expect(new_docs[0]["is_private"]).to eq(false)

        expect(new_docs[1]["uid"]).to eq(@doc.id.to_s)
        expect(new_docs[1]["title"]).to eq(@doc.title)
        expect(new_docs[1]["doc_file"]).to eq(@doc.current_version.doc_file)
        expect(new_docs[1]["version"]).to eq(@doc.current_version.version)
        expect(new_docs[1]["is_unread"]).to eq(false)

        expect(new_docs[1]["is_favourite"]).to eq(true)
        expect(new_docs[1]["category"]).to eq(@doc.category.try(:name).to_s)
        expect(new_docs[1]["is_private"]).to eq(false)
      end

      it "when has two docs & has no favourite doc" do
        @doc1 = create :document, company_id: @company.id, category_id: @category.id
        version1 = create :version, document_id: @doc1.id

        @user.reload

        get 'api/user/docs.json', {token: @user.token, filter: "favourite", company_id: @company.id}

        expect(json["docs"].length).to eq(0)
      end

      it "when has two docs & has a favourite doc" do
        @doc1 = create :document, company_id: @company.id, category_id: @category.id
        version1 = create :version, document_id: @doc1.id

        @user.favourite_document_ids = [@doc.id]
        @user.save

        @user.reload

        get 'api/user/docs.json', {token: @user.token, filter: "favourite", company_id: @company.id}

        expect(json["docs"].length).to eq(1)

        docs = json["docs"]

        expect(docs[0]["uid"]).to eq(@doc.id.to_s)
        expect(docs[0]["title"]).to eq(@doc.title)
        expect(docs[0]["doc_file"]).to eq(@doc.current_version.doc_file)
        expect(docs[0]["version"]).to eq(@doc.current_version.version)
        expect(docs[0]["is_unread"]).to eq(true)

        expect(docs[0]["is_favourite"]).to eq(true)
        expect(docs[0]["category"]).to eq(@doc.category.try(:name).to_s)

        expect(docs[0]["is_private"]).to eq(false)
      end
    end


    context "filter = private" do
      before(:each) do
        User.destroy_all
        Document.destroy_all
        Category.destroy_all

        @user = create :user, company_ids: [@company.id]
        @category = create :category, company_id: @company.id

        @doc = create :document, company_id: @company.id, category_id: @category.id
        version = create :version, document_id: @doc.id
      end

      it "when has a private doc (and also unread)" do
        @doc.update_attributes({is_private: true, private_for_id: @user.id})

        @user.reload

        get 'api/user/docs.json', {token: @user.token, filter: "private", company_id: @company.id}

        expect(json["docs"].length).to eq(1)
        expect(json["unread_number"]).to eq(1)

        new_docs = json["docs"]

        expect(new_docs[0]["uid"]).to eq(@doc.id.to_s)
        expect(new_docs[0]["title"]).to eq(@doc.title)
        expect(new_docs[0]["doc_file"]).to eq(@doc.current_version.doc_file)
        expect(new_docs[0]["version"]).to eq(@doc.current_version.version)

        expect(new_docs[0]["is_unread"]).to eq(true)

        expect(new_docs[0]["is_favourite"]).to eq(false)
        expect(new_docs[0]["category"]).to eq(@doc.category.try(:name).to_s)
        expect(new_docs[0]["is_private"]).to eq(true)

        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
      end

      it "when has no private doc (and also unread)" do
        @doc.update_attributes({is_private: false, private_for_id: nil})

        @user.reload

        get 'api/user/docs.json', {token: @user.token, filter: "private", company_id: @company.id}

        expect(json["docs"].length).to eq(0)
        expect(json["unread_number"]).to eq(0)
      end
    end
  end
end
