require 'spec_helper'

describe "User API" do
  before(:each) do
    create_default_data({create_doc: false})
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
        @user_hash = @user.attributes.except(:id)
      end

      it "when update home_email & password" do
        @user_hash[:uid] = @user.id.to_s
        @user_hash[:home_email] = "abc@gmail.com"
        @user_hash[:password] = "Qwe1rt2yuiop"

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
        @user_hash[:push_token] = "Q2wertyuiopqwertyuiop"
        @user_hash[:app_access_token] = "app1"

        put 'api/user.json', @user_hash
        
        @user.reload

        #expect(json["result"]).to eq(true)
        expect(json["uid"]).to eql(@user.id.to_s)
        expect(json["name"]).to eql(@user.name)
        expect(json["has_setup"]).to eql(@user.has_setup)
        expect(json["home_email"]).to eql(@user.home_email)

        expect(json["has_setup"]).to eql(@user.has_setup)
        expect(@user.has_setup).to eql(true)

        u_device = @user.devices.first

        expect(u_device.token).to eq(@user_hash[:push_token])
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
end