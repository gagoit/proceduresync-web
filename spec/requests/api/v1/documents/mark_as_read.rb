require 'spec_helper'

describe "Document API" do
  before(:each) do
    create_default_data
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
end
