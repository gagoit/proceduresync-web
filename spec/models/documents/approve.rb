require 'spec_helper'

describe "Document: approve!:" do
  context "Approver approve_selected_areas:" do
    before(:each) do
      create_default_data({company_type: :advanced})
      @approver_perm = @company.permissions.where(code: Permission::STANDARD_PERMISSIONS[:approver_user][:code]).first
    end

    # it "when select no area, document will not change the approved areas" do
    #   u_comp = @user.user_company(@company)
    #   u_comp.company_path_ids = @doc.belongs_to_paths.first
    #   u_comp.permission_id = @approver_perm.id
    #   u_comp.approver_path_ids = [@doc.belongs_to_paths.first]
    #   u_comp.save

    #   @user.reload
    #   @company.reload

    #   params = {
    #     document: {
    #       approve_document_to: "approve_selected_areas",
    #       belongs_to_paths: [].to_s
    #     }
    #   }
    #   permit_params = {assign_document_for: params[:document][:approve_document_to]}

    #   result = @doc.approve!(@user, @company, permit_params, params)

    #   @doc.reload

    #   expect(@doc.approved_paths.length).to eq(0)
    #   expect(@doc.approved_by_ids.length).to eq(1)
    #   expect(@doc.approved_by_ids.first).to eq(@user.id)
    #   expect(@doc.approved).to eq(true)
    #   expect(@doc.approver_documents.length).to eq(1)

    #   approver_doc = @doc.approver_documents.first
    #   expect(approver_doc.approve_document_to).to eq(params[:document][:approve_document_to])
    #   expect(approver_doc.approved_paths.length).to eq(0)
    #   expect(approver_doc.not_approved_paths.length).to eq(0)

    #   expect(result[:success]).to eq(true)
    #   expect(result[:message]).to eq(I18n.t("document.approve.success"))
    # end

    # it "when select one area, document will be approved for that area" do
    #   u_comp = @user.user_company(@company)
    #   u_comp.company_path_ids = @doc.belongs_to_paths.first
    #   u_comp.permission_id = @approver_perm.id
    #   u_comp.approver_path_ids = [@doc.belongs_to_paths.first]
    #   u_comp.save

    #   @user.reload
    #   @company.reload

    #   params = {
    #     document: {
    #       approve_document_to: "approve_selected_areas",
    #       belongs_to_paths: [@doc.belongs_to_paths.first].to_s
    #     }
    #   }
    #   permit_params = {assign_document_for: params[:document][:approve_document_to]}

    #   result = @doc.approve!(@user, @company, permit_params, params)

    #   @doc.reload

    #   expect(@doc.approved_paths.length).to eq(1)
    #   expect(@doc.approved_paths.first).to eq(@doc.belongs_to_paths.first)
    #   expect(@doc.approved_by_ids.length).to eq(1)
    #   expect(@doc.approved_by_ids.first).to eq(@user.id)
    #   expect(@doc.approved).to eq(true)
    #   expect(@doc.approver_documents.length).to eq(1)

    #   approver_doc = @doc.approver_documents.first
    #   expect(approver_doc.approve_document_to).to eq(params[:document][:approve_document_to])
    #   expect(approver_doc.approved_paths.length).to eq(1)
    #   expect(approver_doc.not_approved_paths.length).to eq(0)

    #   expect(result[:success]).to eq(true)
    #   expect(result[:message]).to eq(I18n.t("document.approve.success"))
    # end

    # it "when select more than one areas, document will be approved for these areas" do
    #   u_comp = @user.user_company(@company)
    #   u_comp.company_path_ids = @doc.belongs_to_paths.first
    #   u_comp.permission_id = @approver_perm.id
    #   u_comp.approver_path_ids = @all_paths.keys
    #   u_comp.save

    #   @user.reload
    #   @company.reload

    #   params = {
    #     document: {
    #       approve_document_to: "approve_selected_areas",
    #       belongs_to_paths: u_comp.approver_path_ids.to_s
    #     }
    #   }
    #   permit_params = {assign_document_for: params[:document][:approve_document_to]}

    #   result = @doc.approve!(@user, @company, permit_params, params)

    #   @doc.reload

    #   new_approved_paths = @doc.belongs_to_paths & u_comp.approver_path_ids

    #   expect(@doc.approved_paths.length).to eq(new_approved_paths.length)

    #   @doc.approved_paths.each do |area|
    #     expect(u_comp.approver_path_ids.include?(area)).to eq(true)
    #   end
      
    #   expect(@doc.approved_by_ids.length).to eq(1)
    #   expect(@doc.approved_by_ids.first).to eq(@user.id)
    #   expect(@doc.approved).to eq(true)
    #   expect(@doc.approver_documents.length).to eq(1)

    #   approver_doc = @doc.approver_documents.first
    #   expect(approver_doc.approve_document_to).to eq(params[:document][:approve_document_to])
    #   expect(approver_doc.approved_paths.length).to eq(@doc.approved_paths.length)
    #   expect(approver_doc.not_approved_paths.length).to eq(0)

    #   expect(result[:success]).to eq(true)
    #   expect(result[:message]).to eq(I18n.t("document.approve.success"))
    # end

    # it "when select more than one areas but one area was approved before, document will be approved for these areas" do
    #   u_comp = @user.user_company(@company)
    #   u_comp.company_path_ids = @doc.belongs_to_paths.first
    #   u_comp.permission_id = @approver_perm.id
    #   u_comp.approver_path_ids = @all_paths.keys
    #   u_comp.save

    #   @user.reload
    #   @company.reload

    #   @doc.approved_paths = [@doc.belongs_to_paths.first]
    #   @doc.save

    #   @doc.reload

    #   params = {
    #     document: {
    #       approve_document_to: "approve_selected_areas",
    #       belongs_to_paths: @all_paths.keys.to_s
    #     }
    #   }
    #   permit_params = {assign_document_for: params[:document][:approve_document_to]}

    #   result = @doc.approve!(@user, @company, permit_params, params)

    #   @doc.reload

    #   can_approved_paths = @doc.belongs_to_paths & u_comp.approver_path_ids
    #   new_approved_paths = can_approved_paths - [@doc.belongs_to_paths.first]

    #   expect(@doc.approved_paths.length).to eq(can_approved_paths.length)

    #   @doc.approved_paths.each do |area|
    #     expect(u_comp.approver_path_ids.include?(area)).to eq(true)
    #   end
      
    #   expect(@doc.approved_by_ids.length).to eq(1)
    #   expect(@doc.approved_by_ids.first).to eq(@user.id)
    #   expect(@doc.approved).to eq(true)
    #   expect(@doc.approver_documents.length).to eq(1)

    #   approver_doc = @doc.approver_documents.first
    #   expect(approver_doc.approve_document_to).to eq(params[:document][:approve_document_to])
    #   expect(approver_doc.approved_paths.length).to eq(new_approved_paths.length)
    #   expect(approver_doc.not_approved_paths.length).to eq(0)

    #   expect(result[:success]).to eq(true)
    #   expect(result[:message]).to eq(I18n.t("document.approve.success"))
    # end

    # it "when select more than one areas but one area was approved before, document will be approved for these areas" do
    #   u_comp = @user.user_company(@company)
    #   u_comp.company_path_ids = @doc.belongs_to_paths.first
    #   u_comp.permission_id = @approver_perm.id
    #   u_comp.approver_path_ids = @all_paths.keys
    #   u_comp.save

    #   @user.reload
    #   @company.reload

    #   @doc.approved_paths = [@doc.belongs_to_paths.first]
    #   @doc.save

    #   @doc.reload

    #   params = {
    #     document: {
    #       approve_document_to: "approve_selected_areas",
    #       belongs_to_paths: @all_paths.keys.to_s
    #     }
    #   }
    #   permit_params = {assign_document_for: params[:document][:approve_document_to]}

    #   result = @doc.approve!(@user, @company, permit_params, params)

    #   @doc.reload

    #   can_approved_paths = @doc.belongs_to_paths & u_comp.approver_path_ids
    #   new_approved_paths = can_approved_paths - [@doc.belongs_to_paths.first]

    #   expect(@doc.approved_paths.length).to eq(can_approved_paths.length)

    #   @doc.approved_paths.each do |area|
    #     expect(u_comp.approver_path_ids.include?(area)).to eq(true)
    #   end
      
    #   expect(@doc.approved_by_ids.length).to eq(1)
    #   expect(@doc.approved_by_ids.first).to eq(@user.id)
    #   expect(@doc.approved).to eq(true)
    #   expect(@doc.approver_documents.length).to eq(1)

    #   approver_doc = @doc.approver_documents.first
    #   expect(approver_doc.approve_document_to).to eq(params[:document][:approve_document_to])
    #   expect(approver_doc.approved_paths.length).to eq(new_approved_paths.length)
    #   expect(approver_doc.not_approved_paths.length).to eq(0)

    #   expect(result[:success]).to eq(true)
    #   expect(result[:message]).to eq(I18n.t("document.approve.success"))
    # end
  end

  context "Approver approve_all:" do
    before(:each) do
      create_default_data({company_type: :advanced})
      @approver_perm = @company.permissions.where(code: Permission::STANDARD_PERMISSIONS[:approver_user][:code]).first
    end

    it "document will be approved for areas that approver can approve for" do
      u_comp = @user.user_company(@company)
      u_comp.company_path_ids = @doc.belongs_to_paths.first
      u_comp.permission_id = @approver_perm.id
      u_comp.approver_path_ids = [@doc.belongs_to_paths.first]
      u_comp.save

      @user.reload
      @company.reload

      params = {
        document: {
          approve_document_to: "approve_all"
        }
      }
      permit_params = {assign_document_for: params[:document][:approve_document_to]}

      result = @doc.approve!(@user, @company, permit_params, params)

      @doc.reload

      can_approved_paths = @doc.belongs_to_paths & u_comp.approver_path_ids

      expect(@doc.approved_paths.length).to eq(can_approved_paths.length)
      expect(@doc.approved_by_ids.length).to eq(1)
      expect(@doc.approved_by_ids.first).to eq(@user.id)
      expect(@doc.approved).to eq(true)
      expect(@doc.approver_documents.length).to eq(1)

      approver_doc = @doc.approver_documents.first
      expect(approver_doc.approve_document_to).to eq(params[:document][:approve_document_to])
      expect(approver_doc.approved_paths.length).to eq(can_approved_paths.length)
      expect(approver_doc.not_approved_paths.length).to eq(0)

      expect(result[:success]).to eq(true)
      expect(result[:message]).to eq(I18n.t("document.approve.success"))
    end
  end

  context "Approver not_approve:" do
    before(:each) do
      create_default_data({company_type: :advanced})
      @approver_perm = @company.permissions.where(code: Permission::STANDARD_PERMISSIONS[:approver_user][:code]).first
    end

    it "document will be not approved for areas that approver can approve for" do
      u_comp = @user.user_company(@company)
      u_comp.company_path_ids = @doc.belongs_to_paths.first
      u_comp.permission_id = @approver_perm.id
      u_comp.approver_path_ids = [@doc.belongs_to_paths.first]
      u_comp.save

      @user.reload
      @company.reload

      params = {
        document: {
          approve_document_to: "not_approve"
        }
      }
      permit_params = {assign_document_for: params[:document][:approve_document_to]}

      result = @doc.approve!(@user, @company, permit_params, params)

      @doc.reload

      can_approved_paths = @doc.belongs_to_paths & u_comp.approver_path_ids

      can_approved_paths.each do |area|
        expect(@doc.approved_paths.include?(area)).to eq(false)
        expect(@doc.not_approved_paths.include?(area)).to eq(true)
      end
      
      expect(@doc.approved_by_ids.length).to eq(1)
      expect(@doc.approved_by_ids.first).to eq(@user.id)
      expect(@doc.approved).to eq(true)
      expect(@doc.approver_documents.length).to eq(1)

      approver_doc = @doc.approver_documents.first
      expect(approver_doc.approve_document_to).to eq(params[:document][:approve_document_to])
      expect(approver_doc.approved_paths.length).to eq(0)

      expect(approver_doc.not_approved_paths.length).to eq(can_approved_paths.length)
      can_approved_paths.each do |area|
        expect(approver_doc.not_approved_paths.include?(area)).to eq(true)
      end

      expect(result[:success]).to eq(true)
      expect(result[:message]).to eq(I18n.t("document.approve.success"))
    end

    #in case Approver marks a document as "Not Accountable", we will remove accountability from the areas that approver can approve
    it "document will be not approved for areas that approver can approve for (even these areas were approved before)" do
      u_comp = @user.user_company(@company)
      u_comp.company_path_ids = @doc.belongs_to_paths.first
      u_comp.permission_id = @approver_perm.id
      u_comp.approver_path_ids = [@doc.belongs_to_paths.first]
      u_comp.save

      @user.reload
      @company.reload

      @doc.approved_paths = [@doc.belongs_to_paths.first]
      @doc.save
      @doc.reload

      params = {
        document: {
          approve_document_to: "not_approve"
        }
      }
      permit_params = {assign_document_for: params[:document][:approve_document_to]}

      result = @doc.approve!(@user, @company, permit_params, params)

      @doc.reload

      can_approved_paths = @doc.belongs_to_paths & u_comp.approver_path_ids

      can_approved_paths.each do |area|
        expect(@doc.approved_paths.include?(area)).to eq(false)
        expect(@doc.not_approved_paths.include?(area)).to eq(true)
      end

      expect(@doc.approved_paths.length).to eq(0)
      
      expect(@doc.approved_by_ids.length).to eq(1)
      expect(@doc.approved_by_ids.first).to eq(@user.id)
      expect(@doc.approved).to eq(true)
      expect(@doc.approver_documents.length).to eq(1)

      approver_doc = @doc.approver_documents.first
      expect(approver_doc.approve_document_to).to eq(params[:document][:approve_document_to])
      expect(approver_doc.approved_paths.length).to eq(0)

      expect(approver_doc.not_approved_paths.length).to eq(can_approved_paths.length)
      can_approved_paths.each do |area|
        expect(approver_doc.not_approved_paths.include?(area)).to eq(true)
      end

      expect(result[:success]).to eq(true)
      expect(result[:message]).to eq(I18n.t("document.approve.success"))
    end
  end

end