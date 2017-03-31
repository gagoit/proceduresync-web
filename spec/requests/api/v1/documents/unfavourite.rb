require 'spec_helper'

describe "Document API" do
  before(:each) do
    create_default_data
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

      it "when doc isn't expiried & user has already favourited this doc" do
        @user.favour_document!(@doc)

        post 'api/docs/favourite.json', { doc_id: @doc.id.to_s, token: @user.token, type: "unfavourite", company_id: @company.id}
        
        expect(json["result"]).to eql(true)

        @user.reload
        expect(@user.favourite_document_ids.include?(@doc.id)).to eq(false)

        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
      end

      it "when user do this action offline after doc has been changed when user online" do
        post 'api/docs/favourite.json', { doc_id: @doc.id.to_s, token: @user.token, type: "favourite", company_id: @company.id}
        post 'api/docs/favourite.json', { doc_id: @doc.id.to_s, token: @user.token, type: "unfavourite", company_id: @company.id}

        post 'api/docs/favourite.json', { doc_id: @doc.id.to_s, token: @user.token, type: "unfavourite", company_id: @company.id, action_time: (Time.now - 1.day).utc.to_s}
        
        expect(json["result"]).to eql(true)
        expect(json["result_code"]).to eql(SUCCESS_CODES[:rejected])
        expect(json["is_favourite"]).to eq(@user.reload.favourited_doc?(@doc))
      end

      it "when doc has not been favourited by user yet" do
        @user.favourite_document_ids = []
        @user.save

        post 'api/docs/favourite.json', { doc_id: @doc.id.to_s, token: @user.token, type: "unfavourite", company_id: @company.id}
        
        expect(json["result"]).to eql(true)
        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
        expect(json["is_favourite"]).to eq(@user.reload.favourited_doc?(@doc))
      end
    end

    context "errors" do
      before(:each) do
        @user.favour_document!(@doc)
        @user.reload

        @status_before = @user.favourite_document_ids.include?(@doc.id)
      end

      it "when doc is expiried" do
        @doc.update_attribute(:expiry, (Time.now - 1.day).utc)

        post 'api/docs/favourite.json', { doc_id: @doc.id.to_s, token: @user.token, type: "unfavourite", company_id: @company.id}
        
        expect(json["result"]).to eql(nil)
        expect(json["error"]["message"]).to eql(I18n.t("document.is_expiried"))
        expect(json["error"]["error_code"]).to eq(ERROR_CODES[:refresh_data])

        @user.reload
        expect(@user.favourite_document_ids.include?(@doc.id)).to eq(@status_before)
      end

      it "when doc is private" do
        @user1 = create :user, token: "fdsfdsf", company_ids: [@company.id]
        @doc.update_attributes({is_private: true, private_for_id: @user1.id})

        post 'api/docs/favourite.json', { doc_id: @doc.id.to_s, token: @user.token, type: "unfavourite", company_id: @company.id}
        
        expect(json["result"]).to eql(nil)
        expect(json["error"]["message"]).to eql(I18n.t("document.is_private"))
        expect(json["error"]["error_code"]).to eq(ERROR_CODES[:refresh_data])

        @user.reload
        expect(@user.favourite_document_ids.include?(@doc.id)).to eq(@status_before)
      end

      it "when doc is not found" do
        post 'api/docs/favourite.json', { doc_id: "#{@doc.id.to_s}11", token: @user.token, type: "unfavourite", company_id: @company.id}
        
        expect(json["result"]).to eql(nil)
        expect(json["error"]["message"]).to eql(I18n.t("document.not_found"))
        expect(json["error"]["error_code"]).to eq(ERROR_CODES[:item_not_found])
      end
    end
  end
end