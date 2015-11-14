require 'spec_helper'

describe "UserService:" do
  describe "staff_with_outstanding_documents" do

    context "When user has view_all_user_read_receipt_reports permission" do
      before(:each) do
        create_default_data({company_type: :standard})
      end

      it "user can see all users in the users field in Reports" do
        u_comp = @user.user_company(@company)
        u_comp.company_path_ids = @all_paths.keys.first
        u_comp.save
        u_comp.reload

        assign_permission(@user, @company, Permission::STANDARD_PERMISSIONS[:standard_user][:code])

        u_comp_permission = @user.comp_permission(@company)
        u_comp_permission.view_all_user_read_receipt_reports = true
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

        user_ids = ReportService.report_user_ids(@user, @company)

        expect(user_ids.include?(user1.id)).to eq(true)
      end
    end
  end

end