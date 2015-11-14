require 'spec_helper'

describe "Reports API" do
  
  ##
  # Reports: Get companies
  # /reports.json
  # POST
  # @params: 
  #   token
  # @response:  
  #  { 
  #    reports: [ 
  #        {
  #             name: ,
  #             users: [
  #                 { name, unread_number },  
  #                 { name, unread_number }
  #             ]
  #        }, 
  #        {
  #              name: ,
  #              users: []
  #         } 
  #     ] 
  # }"
  describe "GET reports.json" do
    context "success when has only one report" do
      before(:each) do
        User.destroy_all
        Document.destroy_all
        Version.destroy_all
        Company.destroy_all
        Category.destroy_all

        @company = create :company
        @category = create :category
        @user = create :user, company_ids: [@company.id]

        @doc = create :document, company_id: @company.id, category_id: @category.id
        version = create :version, document_id: @doc.id
      end

      it "with company has one user" do
        @user.update_attribute(:read_document_ids, [])

        get 'api/reports.json', { token: @user.token }
        
        expect(json["reports"].length).to eql(1)

        report = json["reports"][0]

        expect(report["name"]).to eql(@company.name)
        expect(report["users"].length).to eql(1)

        users = report["users"]

        expect(users[0]["name"]).to eq(@user.name)
        expect(users[0]["unread_number"]).to eq(1)
        expect(users[0]["docs"].length).to eq(1)

        unread_docs = users[0]["docs"]

        expect(unread_docs[0]["uid"]).to eq(@doc.id.to_s)
        expect(unread_docs[0]["id"]).to eq(@doc.doc_id)
        expect(unread_docs[0]["title"]).to eq(@doc.title)
      end

      it "with company has two users" do
        @user1 = create :user, name: "#{@user.name} rere", token: "dfds", company_ids: [@company.id]

        @user.update_attribute(:read_document_ids, [])

        get 'api/reports.json', { token: @user.token }
        
        expect(json["reports"].length).to eql(1)

        report = json["reports"][0]

        expect(report["name"]).to eql(@company.name)
        expect(report["users"].length).to eql(2)

        users = report["users"]

        expect(users[0]["name"]).to eq(@user.name)
        expect(users[0]["unread_number"]).to eq(1)
        expect(users[0]["docs"].length).to eq(1)

        unread_docs = users[0]["docs"]

        expect(unread_docs[0]["uid"]).to eq(@doc.id.to_s)
        expect(unread_docs[0]["id"]).to eq(@doc.doc_id)
        expect(unread_docs[0]["title"]).to eq(@doc.title)

        expect(users[1]["name"]).to eq(@user1.name)
        expect(users[1]["unread_number"]).to eq(1)
        expect(users[1]["docs"].length).to eq(1)

        unread_docs = users[1]["docs"]

        expect(unread_docs[0]["uid"]).to eq(@doc.id.to_s)
        expect(unread_docs[0]["id"]).to eq(@doc.doc_id)
        expect(unread_docs[0]["title"]).to eq(@doc.title)
      end
    end

  end
end
