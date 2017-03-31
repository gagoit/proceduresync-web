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
    before(:each) do
      create_default_data()
    end

    context "when user isn't supervisor" do
      it "return empty" do
        get 'api/reports.json', { token: @user.token }
        
        expect(json["reports"].length).to eql(0)
        expect(json["result_code"]).to eql(SUCCESS_CODES[:success])
      end
    end

    context "when user is a supervisor" do
      before(:each) do
        assign_permission(@user, @company, Permission::STANDARD_PERMISSIONS[:supervisor_user][:code])
        @u_comp = assign_user_to_path(@user, @company, {company_path_ids: @all_paths.keys.first, supervisor_path_ids: [@all_paths.keys.first]})
      
        # Accountable docs
        @doc.belongs_to_paths << @u_comp.company_path_ids
        @doc.save
      end

      it "return report with users in areas that they supervise (case 1: one user)" do
        user1, u1_comp = create_user(@company, {paths: {company_path_ids: @u_comp.company_path_ids}})

        get 'api/reports.json', { token: @user.token }
        
        expect(json["reports"].length).to eql(1)

        report = json["reports"][0]

        expect(report["name"]).to eql(@company.name)
        expect(report["users"].length).to eql(1)

        users = report["users"]

        expect(users[0]["name"]).to eq(user1.name)
        expect(users[0]["unread_number"]).to eq(1)
        expect(users[0]["docs"].length).to eq(1)

        unread_docs = users[0]["docs"]

        expect(unread_docs[0]["uid"]).to eq(@doc.id.to_s)
        expect(unread_docs[0]["id"]).to eq(@doc.doc_id)
        expect(unread_docs[0]["title"]).to eq(@doc.title)
      end

      it "return report with users in areas that they supervise (case 1: two user)" do
        user1, u1_comp = create_user(@company, {paths: {company_path_ids: @u_comp.company_path_ids}})
        user2, u2_comp = create_user(@company, {paths: {company_path_ids: @u_comp.company_path_ids}})

        get 'api/reports.json', { token: @user.token }
        
        expect(json["reports"].length).to eql(1)

        report = json["reports"][0]

        expect(report["name"]).to eql(@company.name)
        expect(report["users"].length).to eql(2)

        users = report["users"]

        expect(users[0]["name"]).to eq(user1.name)
        expect(users[0]["unread_number"]).to eq(1)
        expect(users[0]["docs"].length).to eq(1)

        u1_unread_docs = users[0]["docs"]

        expect(u1_unread_docs[0]["uid"]).to eq(@doc.id.to_s)
        expect(u1_unread_docs[0]["id"]).to eq(@doc.doc_id)
        expect(u1_unread_docs[0]["title"]).to eq(@doc.title)


        expect(users[1]["name"]).to eq(user2.name)
        expect(users[1]["unread_number"]).to eq(1)
        expect(users[1]["docs"].length).to eq(1)

        u2_unread_docs = users[1]["docs"]

        expect(u2_unread_docs[0]["uid"]).to eq(@doc.id.to_s)
        expect(u2_unread_docs[0]["id"]).to eq(@doc.doc_id)
        expect(u2_unread_docs[0]["title"]).to eq(@doc.title)
      end
    end

  end
end
