require 'spec_helper'

describe "PermissionService" do
  describe "has_permission" do

    context "Action load_company_structure_table in Company controllers" do
      before(:each) do
        create_default_data({company_type: :standard})
      end

      it "user can if user is super admin / super help desk user" do
        can = PermissionService.has_permission(:load_company_structure_table, @admin, @company, @company)
        expect(can).to eq(true)
      end

      it "user can if user has add/edit document permisison" do
        u_comp = @user.user_company(@company)
        u_comp.company_path_ids = @all_paths.keys.first
        u_comp.save
        u_comp.reload

        assign_permission(@user, @company, Permission::STANDARD_PERMISSIONS[:standard_user][:code])

        u_comp_permission = @user.comp_permission(@company)
        u_comp_permission.add_edit_documents = true
        u_comp_permission.save

        @user.reload
        @company.reload

        can = PermissionService.has_permission(:load_company_structure_table, @user, @company, @company)
        expect(can).to eq(true)
      end

      it "user can if user is approver" do
        u_comp = @user.user_company(@company)
        u_comp.company_path_ids = @all_paths.keys.first
        u_comp.save
        u_comp.reload

        assign_permission(@user, @company, Permission::STANDARD_PERMISSIONS[:standard_user][:code])

        u_comp_permission = @user.comp_permission(@company)
        u_comp_permission.is_approval_user = true
        u_comp_permission.save

        @user.reload
        @company.reload

        can = PermissionService.has_permission(:load_company_structure_table, @user, @company, @company)
        expect(can).to eq(true)
      end

      it "user can not if user is not approver/super admin/super help desk user and has not add/edit documents permission" do
        @user.update_attributes(admin: false, super_help_desk_user: false)
        @user.reload

        u_comp = @user.user_company(@company)
        u_comp.company_path_ids = @all_paths.keys.first
        u_comp.save
        u_comp.reload

        assign_permission(@user, @company, Permission::STANDARD_PERMISSIONS[:standard_user][:code])

        u_comp_permission = @user.comp_permission(@company)
        u_comp_permission.is_approval_user = false
        u_comp_permission.save

        @user.reload
        @company.reload

        can = PermissionService.has_permission(:load_company_structure_table, @user, @company, @company)
        expect(can).to eq(false)
      end
    end
  end

  describe "can_bulk_assign_documents" do

    context "When user is admin || super help desk user" do
      before(:each) do
        create_default_data({company_type: :standard, create_doc: false})
      end

      it "user can bulk_assign_documents" do
        expect(PermissionService.can_bulk_assign_documents(@admin, @company)).to eq(true)
        expect(PermissionService.has_permission(:update_paths, @admin, @company, @company.documents.new()) ).to eq(true)
      end
    end

    context "When user don't have bulk_assign_documents and add_edit_documents permission" do
      before(:each) do
        create_default_data({company_type: :advanced, create_doc: false})
      end

      it "user can not bulk_assign_documents" do
        u_comp = @user.user_company(@company)
        u_comp.company_path_ids = @all_paths.keys.first
        u_comp.save
        u_comp.reload

        assign_permission(@user, @company, Permission::STANDARD_PERMISSIONS[:approver_user][:code])
        u_comp_permission = @user.comp_permission(@company)
        u_comp_permission.add_edit_documents = false
        u_comp_permission.bulk_assign_documents = false
        u_comp_permission.save

        @user.reload
        @company.reload

        expect(PermissionService.can_bulk_assign_documents(@user, @company)).to eq(false)
        expect(PermissionService.has_permission(:update_paths, @user, @company, @company.documents.new()) ).to eq(false)
      end
    end

    context "When user have one of bulk_assign_documents or add_edit_documents permission" do
      before(:each) do
        create_default_data({company_type: :advanced, create_doc: false})
      end

      it "user can bulk_assign_documents" do
        u_comp = @user.user_company(@company)
        u_comp.company_path_ids = @all_paths.keys.first
        u_comp.save
        u_comp.reload

        #just has bulk_assign_documents
        assign_permission(@user, @company, Permission::STANDARD_PERMISSIONS[:approver_user][:code])
        u_comp_permission = @user.comp_permission(@company)
        u_comp_permission.add_edit_documents = false
        u_comp_permission.bulk_assign_documents = true
        u_comp_permission.save

        @user.reload
        @company.reload

        expect(PermissionService.can_bulk_assign_documents(@user, @company)).to eq(true)
        expect(PermissionService.has_permission(:update_paths, @user, @company, @company.documents.new()) ).to eq(true)

        #just has add_edit_documents
        u_comp_permission = @user.comp_permission(@company)
        u_comp_permission.add_edit_documents = true
        u_comp_permission.bulk_assign_documents = false
        u_comp_permission.save

        @user.reload
        @company.reload

        expect(PermissionService.can_bulk_assign_documents(@user, @company)).to eq(true)
        expect(PermissionService.has_permission(:update_paths, @user, @company, @company.documents.new()) ).to eq(true)
      end
    end
  end


  describe "available_areas_for_bulk_assign_documents" do

    context "When user is admin || super help desk user" do
      before(:each) do
        create_default_data({company_type: :standard, create_doc: false})
      end

      it "user can do bulk_assign_documents for all company paths" do
        paths = PermissionService.available_areas_for_bulk_assign_documents(@admin, @company)

        expect(paths.length).to eq(@all_paths.keys.length)

        paths.each do |e|
          expect(@all_paths.keys.include?(e)).to eq(true)
        end
      end
    end

    context "When user don't have bulk_assign_documents and add_edit_documents permission" do
      before(:each) do
        create_default_data({company_type: :advanced, create_doc: false})
      end

      it "user can not do bulk_assign_documents for any areas" do
        u_comp = @user.user_company(@company)
        u_comp.company_path_ids = @all_paths.keys.first
        u_comp.save
        u_comp.reload

        assign_permission(@user, @company, Permission::STANDARD_PERMISSIONS[:approver_user][:code])
        u_comp_permission = @user.comp_permission(@company)
        u_comp_permission.add_edit_documents = false
        u_comp_permission.bulk_assign_documents = false
        u_comp_permission.save

        @user.reload
        @company.reload

        paths = PermissionService.available_areas_for_bulk_assign_documents(@user, @company)

        expect(paths.blank?).to eq(true)
      end
    end

    context "When user is approver and have one of bulk_assign_documents or add_edit_documents permission" do
      before(:each) do
        create_default_data({company_type: :advanced, create_doc: false})
      end

      it "user can bulk_assign_documents, not add_edit_documents, not is supervisor, user will only do bulk_assign_documents for approve for areas" do
        u_comp = @user.user_company(@company)
        u_comp.company_path_ids = @all_paths.keys.first
        u_comp.save
        u_comp.reload
        @user.reload

        #just has bulk_assign_documents
        assign_permission(@user, @company, Permission::STANDARD_PERMISSIONS[:approver_user][:code])

        u_comp.reload
        u_comp.approver_path_ids = [@all_paths.keys.first]
        u_comp.save

        u_comp_permission = @user.comp_permission(@company)
        u_comp_permission.add_edit_documents = false
        u_comp_permission.bulk_assign_documents = true
        u_comp_permission.save

        @user.reload
        @company.reload

        paths = PermissionService.available_areas_for_bulk_assign_documents(@user, @company)

        expect(paths.length).to eq(1)
        expect(paths.first).to eq(@all_paths.keys.first)
      end

      it "user can add_edit_documents, not bulk_assign_documents, not is supervisor, user will only do bulk_assign_documents for all areas" do
        u_comp = @user.user_company(@company)
        u_comp.company_path_ids = @all_paths.keys.first
        u_comp.save
        u_comp.reload

        #just has bulk_assign_documents
        assign_permission(@user, @company, Permission::STANDARD_PERMISSIONS[:approver_user][:code])

        #just has add_edit_documents
        u_comp_permission = @user.comp_permission(@company)
        u_comp_permission.add_edit_documents = true
        u_comp_permission.bulk_assign_documents = false
        u_comp_permission.save

        @user.reload
        @company.reload

        paths = PermissionService.available_areas_for_bulk_assign_documents(@user, @company)

        expect(paths.length).to eq(@all_paths.keys.length)

        paths.each do |e|
          expect(@all_paths.keys.include?(e)).to eq(true)
        end
      end

      it "user has bulk_assign_documents, not add_edit_documents, and is supervisor, user will only do bulk_assign_documents for approve for areas + superviso for areas" do
        u_comp = @user.user_company(@company)
        u_comp.company_path_ids = @all_paths.keys.first
        u_comp.save
        u_comp.reload
        @user.reload

        #just has bulk_assign_documents
        assign_permission(@user, @company, Permission::STANDARD_PERMISSIONS[:approver_user][:code])

        u_comp_permission = @user.comp_permission(@company)
        u_comp_permission.add_edit_documents = false
        u_comp_permission.bulk_assign_documents = true
        u_comp_permission.is_supervisor_user = true
        u_comp_permission.save

        @user.reload
        @company.reload
        u_comp.reload
        u_comp.approver_path_ids = [@all_paths.keys.first]
        u_comp.supervisor_path_ids = @all_paths.keys - u_comp.approver_path_ids
        u_comp.save

        @user.reload

        available_paths = (u_comp.approver_path_ids + u_comp.supervisor_path_ids)
        available_paths.uniq!

        paths = PermissionService.available_areas_for_bulk_assign_documents(@user, @company)

        expect(paths.length).to eq(available_paths.length)

        paths.each do |e|
          expect(available_paths.include?(e)).to eq(true)
        end
      end
    end
  end
end