require 'spec_helper'

describe "User API" do
  before(:each) do
    create_default_data({create_doc: false})
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
        @password = "ODKfdsadat1aaasw2"
      end

      it "& return user in db" do
        @user.password = @password
        @user.save
        
        post 'api/user/token.json', { email: @user.email, password: @password }
        
        @user.reload
        expect(json["uid"]).to eql(@user.id.to_s)
        expect(json["name"]).to eql(@user.name)
        expect(json["has_setup"]).to eql(@user.has_setup)
        expect(json["home_email"]).to eql(@user.home_email)
        expect(json["token"]).to eq(@user.token)

        expect(json["companies"].length).to eql(1)

        company = json["companies"].first

        expect(company["name"]).to eql(@company.name)
        expect(company["uid"]).to eql(@company.id.to_s)
        expect(company["logo_url"]).to eql(@company.logo_iphone4_url)

        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
      end

      it "& return error when user is inactive" do
        @user.active = false
        @user.password = @password
        @user.save
        
        post 'api/user/token.json' , {email: @user.email, password: @password}

        expect(json["error"]["message"]).to eql(I18n.t("user.disabled"))
        expect(json["error"]["error_code"]).to eql(ERROR_CODES[:user_is_inactive])
      end

      it "& return error when user has no company" do
        @user.remove_company(@company)

        @user.password = @password
        @user.company_ids.delete(@company.id)
        @user.save
        
        post 'api/user/token.json' , {email: @user.email, password: @password}

        expect(json["error"]["message"]).to eql(I18n.t("company.is_inactive"))
        expect(json["error"]["error_code"]).to eql(ERROR_CODES[:user_is_inactive])
      end

      it "& return error when user has just one company and company is inactive" do
        @user.password = @password
        @user.save

        @company.active = false
        @company.save
        
        post 'api/user/token.json' , {email: @user.email, password: @password}

        expect(json["error"]["message"]).to eql(I18n.t("company.is_inactive"))
        expect(json["error"]["error_code"]).to eql(ERROR_CODES[:user_is_inactive])
      end

      it "& return error when user not found" do
        post 'api/user/token.json' , {email: "1"}

        expect(json["error"]["message"]).to eql(I18n.t("user.email_not_found"))
        expect(json["error"]["error_code"]).to eql(ERROR_CODES[:item_not_found])
      end

      it "& return error when password is wrong" do
        @user.password = @password
        @user.save
        
        post 'api/user/token.json' , {email: @user.email, password: "#{@password}11"}

        expect(json["error"]["message"]).to eql(I18n.t("user.password_invalid"))
        expect(json["error"]["error_code"]).to eql(ERROR_CODES[:invalid_value])
      end

      it "When signing-in, email address can be case insensitive" do
        @user.password = @password
        @user.save
        
        post 'api/user/token.json' , {email: @user.email.upcase, password: @password}
        
        @user.reload

        expect(json["uid"]).to eql(@user.id.to_s)
        expect(json["name"]).to eql(@user.name)
        expect(json["has_setup"]).to eql(@user.has_setup)
        expect(json["home_email"]).to eql(@user.home_email)
        expect(json["token"]).to eq(@user.token)

        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
      end
    end
  end
end
