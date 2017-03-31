require 'spec_helper'

describe "User API" do
  before(:each) do
    create_default_data({create_doc: false})
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
      end

      it "when user is found in db" do
        Delayed::Job.destroy_all
        
        post 'api/user/forgot_password.json', { email: @user.email}

        @user.reload

        expect(json["result"]).to eql(true)
        expect(@user.has_setup).to eql(false)
        expect(Delayed::Job.count).to eq(1)

        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
      end

      it "return error when user is not in db" do        
        post 'api/user/forgot_password.json', { email: "sss"}
        
        expect(json["error"]["message"]).to eql(I18n.t("user.email_not_found"))
        expect(json["error"]["error_code"]).to eql(ERROR_CODES[:item_not_found])
      end
    end
  end
end