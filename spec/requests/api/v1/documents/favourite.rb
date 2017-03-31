require 'spec_helper'

describe "Document API" do
  before(:each) do
    create_default_data
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
    context "return success" do

      it "when doc isn't expiried & user has not favourited this doc yet" do
        post 'api/docs/favourite.json', { doc_id: @doc.id.to_s, token: @user.token, type: "favourite", company_id: @company.id}
        
        expect(json["result"]).to eql(true)
        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])

        @user.reload
        expect(@user.favourite_document_ids.include?(@doc.id)).to eq(true)
      end

      it "when doc has already been favourited by user" do
        @user.favourite_document_ids = [@doc.id]
        @user.save

        post 'api/docs/favourite.json', { doc_id: @doc.id.to_s, token: @user.token, type: "favourite", company_id: @company.id}
        
        expect(json["result"]).to eql(true)
        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])

        @user.reload
        expect(@user.favourite_document_ids.include?(@doc.id)).to eq(true)
      end

      it "when user do this action offline after doc has been changed when user online" do
        post 'api/docs/favourite.json', { doc_id: @doc.id.to_s, token: @user.token, type: "favourite", company_id: @company.id}

        post 'api/docs/favourite.json', { doc_id: @doc.id.to_s, token: @user.token, type: "favourite", company_id: @company.id, action_time: (Time.now - 1.day).utc.to_s}
        
        expect(json["result"]).to eql(true)
        expect(json["result_code"]).to eql(SUCCESS_CODES[:rejected])

        @user.reload
        expect(@user.favourite_document_ids.include?(@doc.id)).to eq(true)
      end
    end

    context "return error" do
      
      it "when doc is expiried" do
        @doc.update_attribute(:expiry, (Time.now - 1.day).utc)
        post 'api/docs/favourite.json', { doc_id: @doc.id.to_s, token: @user.token, type: "favourite", company_id: @company.id}
        
        expect(json["result"]).to eql(nil)
        expect(json["error"]["message"]).to eql(I18n.t("document.is_expiried"))
        expect(json["error"]["error_code"]).to eq(ERROR_CODES[:refresh_data])

        @user.reload
        expect(@user.favourite_document_ids.include?(@doc.id)).to eq(false)
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
end