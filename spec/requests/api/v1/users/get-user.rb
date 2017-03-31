require 'spec_helper'

describe "User API" do
  before(:each) do
    create_default_data({create_doc: false})
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
      end

      it "return user on db" do
        get 'api/user.json', {uid: @user.id.to_s, token: @user.token}
        
        expect(json["uid"]).to eql(@user.id.to_s)
        expect(json["name"]).to eql(@user.name)
        expect(json["has_setup"]).to eql(@user.has_setup)
        expect(json["home_email"]).to eql(@user.home_email)

        expect(json["token"]).to eq(@user.token)
        expect(json["companies"].length).to eq(1)

        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
      end

      it "& return error when user not found" do
        get 'api/user.json' , {uid: 1, token: ""}

        expect(json["error"]["message"]).to eql(I18n.t("user.null_or_invalid_token"))
        expect(json["error"]["error_code"]).to eql(ERROR_CODES[:invalid_value])
      end
    end
  end
end
