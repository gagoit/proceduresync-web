require 'spec_helper'

describe "ReportService" do
  describe "report_user_ids" do

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


    context "When user just has view_all_user_read_receipt_reports_under_assignment permission" do
      before(:each) do
        create_default_data({company_type: :standard})
      end

      it "if user is not approver/supervisor, user can see only users in their area" do
        u_comp = @user.user_company(@company)
        u_comp.company_path_ids = @all_paths.keys.first
        u_comp.save
        u_comp.reload

        assign_permission(@user, @company, Permission::STANDARD_PERMISSIONS[:standard_user][:code])

        u_comp_permission = @user.comp_permission(@company)
        u_comp_permission.view_all_user_read_receipt_reports_under_assignment = true
        u_comp_permission.view_all_user_read_receipt_reports = false
        u_comp_permission.save

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

        user_ids = ReportService.report_user_ids(@user, @company)

        expect(user_ids.include?(user1.id)).to eq(false)
        expect(user_ids.include?(user2.id)).to eq(true)
      end

      it "if user is supervisor, user can see users in their area and users in areas that they supervise" do
        u_comp = @user.user_company(@company)
        u_comp.company_path_ids = @all_paths.keys.first
        u_comp.save
        u_comp.reload

        assign_permission(@user, @company, Permission::STANDARD_PERMISSIONS[:standard_user][:code])

        u_comp_permission = @user.comp_permission(@company)
        u_comp_permission.view_all_user_read_receipt_reports_under_assignment = true
        u_comp_permission.view_all_user_read_receipt_reports = false
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

        user_ids = ReportService.report_user_ids(@user, @company)

        expect(user_ids.include?(user1.id)).to eq(true)
        expect(user_ids.include?(user2.id)).to eq(true)
      end

      it "if user is approver, user can see users in their area and users in areas that they approve" do
        u_comp = @user.user_company(@company)
        u_comp.company_path_ids = @all_paths.keys.first
        u_comp.save
        u_comp.reload

        assign_permission(@user, @company, Permission::STANDARD_PERMISSIONS[:standard_user][:code])

        u_comp_permission = @user.comp_permission(@company)
        u_comp_permission.view_all_user_read_receipt_reports_under_assignment = true
        u_comp_permission.view_all_user_read_receipt_reports = false
        u_comp_permission.is_approval_user = true
        u_comp_permission.save

        u_comp.approver_path_ids = (@all_paths.keys - [u_comp.company_path_ids])
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

        user_ids = ReportService.report_user_ids(@user, @company)

        expect(user_ids.include?(user1.id)).to eq(true)
        expect(user_ids.include?(user2.id)).to eq(true)
      end
    end


    context "When user has no view_all_user_read_receipt_reports, view_all_user_read_receipt_reports_under_assignment permission" do
      before(:each) do
        create_default_data({company_type: :standard})
      end

      it "user can see only themselves in the users field in Reports" do
        u_comp = @user.user_company(@company)
        u_comp.company_path_ids = @all_paths.keys.first
        u_comp.save
        u_comp.reload

        assign_permission(@user, @company, Permission::STANDARD_PERMISSIONS[:standard_user][:code])

        u_comp_permission = @user.comp_permission(@company)
        u_comp_permission.view_all_user_read_receipt_reports = false
        u_comp_permission.view_all_user_read_receipt_reports_under_assignment = false
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

        expect(user_ids.include?(user1.id)).to eq(false)
      end
    end
  end


  describe "company_paths_for_accountability_report" do

    context "When user has view_all_accountability_reports permission" do
      before(:each) do
        create_default_data({company_type: :standard})
      end

      it "user can see all areas" do
        u_comp = @user.user_company(@company)
        u_comp.company_path_ids = @all_paths.keys.first
        u_comp.save

        assign_permission(@user, @company, Permission::STANDARD_PERMISSIONS[:standard_user][:code])

        u_comp_permission = @user.comp_permission(@company)
        u_comp_permission.view_all_accountability_reports = true
        u_comp_permission.save
        @user.reload

        areas = ReportService.company_paths_for_accountability_report(@user, @company)
        areas = areas.map { |e| e[1] }

        @all_paths.keys.each do |area|
          expect(areas.include?(area)).to eq(true)
        end
      end
    end


    context "When user just has view_accountability_reports_under_assignment permission" do
      before(:each) do
        create_default_data({company_type: :standard})
      end

      it "if user is not approver/supervisor, user can see only their area" do
        u_comp = @user.user_company(@company)
        u_comp.company_path_ids = @all_paths.keys.first
        u_comp.save

        assign_permission(@user, @company, Permission::STANDARD_PERMISSIONS[:standard_user][:code])

        u_comp_permission = @user.comp_permission(@company)
        u_comp_permission.view_accountability_reports_under_assignment = true
        u_comp_permission.view_all_accountability_reports = false
        u_comp_permission.save
        @user.reload

        areas = ReportService.company_paths_for_accountability_report(@user, @company)
        areas = areas.map { |e| e[1] }

        expect(areas.include?(u_comp.company_path_ids)).to eq(true)
        expect(areas.length).to eq(1)
      end

      it "if user is supervisor, user can see users in their area and users in areas that they supervise" do
        u_comp = @user.user_company(@company)
        u_comp.company_path_ids = @all_paths.keys.first
        u_comp.save
        u_comp.reload

        assign_permission(@user, @company, Permission::STANDARD_PERMISSIONS[:standard_user][:code])

        u_comp_permission = @user.comp_permission(@company)
        u_comp_permission.view_accountability_reports_under_assignment = true
        u_comp_permission.view_all_accountability_reports = false
        u_comp_permission.is_supervisor_user = true
        u_comp_permission.save

        u_comp.supervisor_path_ids = (@all_paths.keys - [u_comp.company_path_ids])
        u_comp.save
        @user.reload

        areas = ReportService.company_paths_for_accountability_report(@user, @company)
        areas = areas.map { |e| e[1] }

        can_see_areas = (u_comp.supervisor_path_ids + [u_comp.company_path_ids])
        can_see_areas.each do |area|
          expect(areas.include?(area)).to eq(true)
        end

        expect(can_see_areas.length).to eq(areas.length)
      end

      it "if user is approver, user can see users in their area and users in areas that they approve" do
        u_comp = @user.user_company(@company)
        u_comp.company_path_ids = @all_paths.keys.first
        u_comp.save
        u_comp.reload

        assign_permission(@user, @company, Permission::STANDARD_PERMISSIONS[:standard_user][:code])

        u_comp_permission = @user.comp_permission(@company)
        u_comp_permission.view_accountability_reports_under_assignment = true
        u_comp_permission.view_all_accountability_reports = false
        u_comp_permission.is_approval_user = true
        u_comp_permission.save

        u_comp.approver_path_ids = (@all_paths.keys - [u_comp.company_path_ids])
        u_comp.save
        @user.reload

        areas = ReportService.company_paths_for_accountability_report(@user, @company)
        areas = areas.map { |e| e[1] }

        can_see_areas = (u_comp.approver_path_ids + [u_comp.company_path_ids])
        can_see_areas.each do |area|
          expect(areas.include?(area)).to eq(true)
        end

        expect(can_see_areas.length).to eq(areas.length)
      end
    end


    context "When user has no view_all_accountability_reports, view_accountability_reports_under_assignment permission" do
      before(:each) do
        create_default_data({company_type: :standard})
      end

      it "user can see only their area in the users field in Reports" do
        u_comp = @user.user_company(@company)
        u_comp.company_path_ids = @all_paths.keys.first
        u_comp.save
        u_comp.reload

        assign_permission(@user, @company, Permission::STANDARD_PERMISSIONS[:standard_user][:code])

        u_comp_permission = @user.comp_permission(@company)
        u_comp_permission.view_all_accountability_reports = false
        u_comp_permission.view_accountability_reports_under_assignment = false
        u_comp_permission.save
        @user.reload

        areas = ReportService.company_paths_for_accountability_report(@user, @company)
        areas = areas.map { |e| e[1] }

        can_see_areas = [u_comp.company_path_ids]
        can_see_areas.each do |area|
          expect(areas.include?(area)).to eq(true)
        end

        expect(can_see_areas.length).to eq(areas.length)
      end
    end
  end
end