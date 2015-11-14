require 'spec_helper'

describe "Base API" do
 
  describe "Require token" do
    context "works" do
      it "for POST /docs/mark_as_read.json" do

        post 'api/docs/mark_as_read.json'

        expect(json["error"]["message"]).to eql(I18n.t('user.null_or_invalid_token'))
      end

      it "for POSt /docs/favourite.json" do

        post 'api/docs/favourite.json'

        expect(json["error"]["message"]).to eql(I18n.t('user.null_or_invalid_token'))
      end

      it "for GET /user/docs.json" do

        get 'api/user/docs.json'

        expect(json["error"]["message"]).to eql(I18n.t('user.null_or_invalid_token'))
      end

      it "for GET api/categories.json" do

        get 'api/categories.json'

        expect(json["error"]["message"]).to eql(I18n.t('user.null_or_invalid_token'))
      end
    end
  end

end
