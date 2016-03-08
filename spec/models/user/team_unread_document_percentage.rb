require 'spec_helper'

describe "User: team_unread_document_percentage" do

  test_formula = lambda { |user, company, user_ids| 
    ## Calculate unread_docs_count,accountable_docs_count
    unread = 0
    total = 0
    user_ids.each do |id|
      u_c = company.user_companies.includes(:user).active.where(:user_id => id).first
      u_c.user.update_docs_count(company, u_c)

      u_c.reload

      unread += u_c.unread_docs_count
      total += u_c.accountable_docs_count
    end

    unread_percentage = user.team_unread_document_percentage(company)

    return unread_percentage.to_s, ((unread/total.to_f)*100).round(2).to_s
  }


  context "When user don't have is_supervisor_user" do
    before(:each) do
      create_default_data({company_type: :standard})
    end

    it "user will see team_unread_document_percentage as 0" do
      u_comp = @user.user_company(@company)
      u_comp.company_path_ids = @all_paths.keys.first
      u_comp.save
      u_comp.reload

      assign_permission(@user, @company, Permission::STANDARD_PERMISSIONS[:standard_user][:code])

      u_comp_permission = @user.comp_permission(@company)
      u_comp_permission.view_all_user_read_receipt_reports = true
      u_comp_permission.is_supervisor_user = false
      u_comp_permission.save

      user1 = create :user, token: "#{@user.token}11", company_ids: [@company.id], admin: false
      user1.reload
      @company.reload

      User.update_companies_of_user(user1, [], [@company.id])
      u1_comp = user1.user_company(@company)
      u1_comp.company_path_ids = (@all_paths.keys - [u_comp.company_path_ids]).first
      u1_comp.save

      @user.reload
      user1.reload

      unread_percentage, unread_percentage_r = test_formula.call(@user, @company, [])
      expect(unread_percentage).to eq("0")
    end
  end


  context "When user has is_supervisor_user permission" do
    before(:each) do
      create_default_data({company_type: :standard})
    end

    it "if user is supervisor, user can see team_unread_document_percentage" do
      u_comp = @user.user_company(@company)
      u_comp.company_path_ids = @all_paths.keys.first
      u_comp.save
      u_comp.reload

      assign_permission(@user, @company, Permission::STANDARD_PERMISSIONS[:standard_user][:code])

      u_comp_permission = @user.comp_permission(@company)
      u_comp_permission.is_supervisor_user = true
      u_comp_permission.save

      u_comp.supervisor_path_ids = (@all_paths.keys - [u_comp.company_path_ids])
      u_comp.save

      #user1 is not in @user's area
      user1 = create :user, token: "#{@user.token}11", company_ids: [@company.id], admin: false
      user1.reload
      @company.reload

      User.update_companies_of_user(user1, [], [@company.id])
      u1_comp = user1.user_company(@company)
      u1_comp.company_path_ids = (@all_paths.keys - [u_comp.company_path_ids]).first
      u1_comp.save

      #user2 is in @user's area
      user2 = create :user, token: "#{@user.token}111", company_ids: [@company.id], admin: false
      user2.reload
      @company.reload
      
      User.update_companies_of_user(user2, [], [@company.id])
      u2_comp = user2.user_company(@company)
      u2_comp.company_path_ids = u_comp.company_path_ids
      u2_comp.save

      @user.reload
      user1.reload
      user2.reload

      user_ids = [user1.id]

      unread_percentage, unread_percentage_r = test_formula.call(@user, @company, user_ids)
      expect(unread_percentage).to eq(unread_percentage_r)
    end

  end
end