require 'spec_helper'

describe "User: docs:" do
  context "Standard Company, filter = favourite:" do
    before(:each) do
      create_default_data({company_type: :standard})
    end

    it "when user has favourited no doc" do
      u_comp = @user.user_company(@company)
      u_comp.company_path_ids = @doc.belongs_to_paths.first
      u_comp.save

      new_docs = @user.docs(@company, "favourite")

      expect(new_docs[:docs].count).to eq(0)
      expect(new_docs[:unread_number]).to eq(0)
    end

    it "when user has favourited one accountable doc and user has not read it yet" do
      u_comp = @user.user_company(@company)
      u_comp.company_path_ids = @doc.belongs_to_paths.first
      u_comp.save

      @user.favour_document!(@doc)

      new_docs = @user.docs(@company, "favourite")

      expect(new_docs[:docs].count).to eq(1)
      expect(new_docs[:unread_number]).to eq(1)

      expect(new_docs[:docs].first.id).to eq(@doc.id)
    end

    it "when user has favourited one doc and user has already read it" do
      u_comp = @user.user_company(@company)
      u_comp.company_path_ids = @doc.belongs_to_paths.first
      u_comp.save

      @user.favour_document!(@doc)
      @user.read_document!(@doc)

      new_docs = @user.docs(@company, "favourite")

      expect(new_docs[:docs].count).to eq(1)
      expect(new_docs[:unread_number]).to eq(0)

      expect(new_docs[:docs].first.id).to eq(@doc.id)
    end
  end

  context "Company Standard, filter = unread" do
    before(:each) do
      create_default_data({company_type: :standard})
    end

    it "when user has read no doc" do
      u_comp = @user.user_company(@company)
      u_comp.company_path_ids = @doc.belongs_to_paths.first
      u_comp.save
      @user.reload

      new_docs = @user.docs(@company, "unread")

      expect(new_docs[:docs].count).to eq(1)
      expect(new_docs[:unread_number]).to eq(1)

      expect(new_docs[:docs].first.id).to eq(@doc.id)
    end

    it "when user can see one doc, and user has read one doc" do
      u_comp = @user.user_company(@company)
      u_comp.company_path_ids = @doc.belongs_to_paths.first
      u_comp.save
      @user.reload

      new_docs = @user.docs(@company, "unread")

      expect(new_docs[:docs].count).to eq(1)
      expect(new_docs[:unread_number]).to eq(1)

      expect(new_docs[:docs].first.id).to eq(@doc.id)
    end

    it "when user can see two docs, and user has read one doc" do
      u_comp = @user.user_company(@company)
      u_comp.company_path_ids = @doc.belongs_to_paths.first
      u_comp.save

      @doc1.belongs_to_paths << u_comp.company_path_ids
      @doc1.save

      @user.read_document!(@doc)
      @user.reload

      new_docs = @user.docs(@company, "unread")

      expect(new_docs[:docs].count).to eq(1)
      expect(new_docs[:unread_number]).to eq(1)

      expect(new_docs[:docs].first.id).to eq(@doc1.id)
    end
  end

  context "Company Standard, filter = private" do
    before(:each) do
      create_default_data({company_type: :standard})
    end

    it "when user has no private doc" do
      u_comp = @user.user_company(@company)
      u_comp.company_path_ids = @all_paths.keys.first
      u_comp.save

      new_docs = @user.docs(@company, "private")

      expect(new_docs[:docs].count).to eq(0)
      expect(new_docs[:unread_number]).to eq(0)
    end

    it "when user has one private doc" do
      u_comp = @user.user_company(@company)
      u_comp.company_path_ids = @all_paths.keys.first
      u_comp.save

      private_doc, private_version = create_private_doc(@user, @company)

      new_docs = @user.docs(@company, "private")

      expect(new_docs[:docs].count).to eq(1)
      expect(new_docs[:unread_number]).to eq(0)

      expect(new_docs[:docs].first.id).to eq(private_doc.id)
    end
  end

  context "Advanced Company, filter = to_approve" do
    before(:each) do
      create_default_data({company_type: :advanced})
    end

    it "when user is not approver, user will see no docs" do
      u_comp = @user.user_company(@company)
      u_comp.company_path_ids = @doc.belongs_to_paths.first
      u_comp.save

      new_docs = @user.docs(@company, "to_approve")

      expect(new_docs[:docs].count).to eq(0)
    end

    it "when user is approver, however no docs are in his org part, user will see no docs" do
      u_comp = @user.user_company(@company)
      perm = @company.permissions.where(code: Permission::STANDARD_PERMISSIONS[:approver_user][:code]).first

      u_comp.company_path_ids = @all_paths.keys.first
      u_comp.permission_id = perm.id
      u_comp.approver_path_ids = (@all_paths.keys - @doc.belongs_to_paths)
      u_comp.save

      new_docs = @user.docs(@company, "to_approve")

      expect(new_docs[:docs].count).to eq(0)
    end

    it "when user is approver, and has one doc in his org part, user will see this doc" do
      u_comp = @user.user_company(@company)
      perm = @company.permissions.where(code: Permission::STANDARD_PERMISSIONS[:approver_user][:code]).first

      u_comp.company_path_ids = @all_paths.keys.first
      u_comp.permission_id = perm.id
      u_comp.approver_path_ids = [@doc.belongs_to_paths.first]
      u_comp.save

      @user.reload

      new_docs = @user.docs(@company, "to_approve")

      expect(new_docs[:docs].count).to eq(1)
      expect(new_docs[:docs].first.id).to eq(@doc.id)
    end

    it "when user is approver, has one doc in his org part and he's already approved it, but there was another approver set this doc as not-accountable for the ares that user can approve for => user will see this doc" do
      @doc.belongs_to_paths = @all_paths.keys
      @doc.save

      @doc1.destroy

      u_comp = @user.user_company(@company)
      perm = @company.permissions.where(code: Permission::STANDARD_PERMISSIONS[:approver_user][:code]).first

      u_comp.company_path_ids = @all_paths.keys.first
      u_comp.permission_id = perm.id
      u_comp.approver_path_ids = @doc.belongs_to_paths
      u_comp.save

      @user.reload

      new_docs = @user.docs(@company, "to_approve")

      expect(new_docs[:docs].count).to eq(1)
      expect(new_docs[:docs].first.id).to eq(@doc.id)

      @doc.approve!(@user, @company, {}, {document: {curr_version: @doc.curr_version, belongs_to_paths: [@doc.belongs_to_paths.first].to_s, approve_document_to: "approve_selected_areas"}})
    
      @doc.reload

      new_docs = @user.docs(@company, "to_approve")

      expect(new_docs[:docs].count).to eq(0)

      # another approver set this doc as not-accountable for the ares that user can approve for
      @user_1 = create :user, token: "#{@user.token}2", company_ids: [@company.id], admin: false
      @company.reload
      u_comp_1 = @user_1.user_company(@company)
      perm = @company.permissions.where(code: Permission::STANDARD_PERMISSIONS[:approver_user][:code]).first

      u_comp_1.company_path_ids = @all_paths.keys.first
      u_comp_1.permission_id = perm.id
      u_comp_1.approver_path_ids = @doc.belongs_to_paths
      u_comp_1.save

      @user_1.reload

      new_docs = @user_1.docs(@company, "to_approve")

      expect(new_docs[:docs].count).to eq(1)
      expect(new_docs[:docs].first.id).to eq(@doc.id)

      # After user_1 set this doc as not-accountable for his areas, he can't see this doc in For Approval filter again.
      @doc.approve!(@user_1, @company, {}, {document: {curr_version: @doc.curr_version, belongs_to_paths: "", approve_document_to: "not_approve"}})
    
      @doc.reload

      new_docs = @user_1.docs(@company, "to_approve")

      expect(new_docs[:docs].count).to eq(0)

      # After user_1 set this doc as not-accountable for his areas, user can see this docs in For Approval filter again
      new_docs = @user.docs(@company, "to_approve")

      expect(new_docs[:docs].count).to eq(1)
      expect(new_docs[:docs].first.id).to eq(@doc.id)
    end
  end

  context "Advanced Company, search to be approve documents:" do
    before(:each) do
      create_default_data({company_type: :advanced})
    end

    it "User can see to be approve documents if these are not restricted and not accountable for user" do
      u_comp = @user.user_company(@company)
      u_comp.company_path_ids = (@all_paths.keys - @doc.belongs_to_paths).first
      u_comp.save
      @user.reload

      new_docs = @user.docs(@company, "all")

      expect(new_docs[:docs].count).to_not eq(0)
      new_doc_ids = new_docs[:docs].pluck(:id)

      expect(new_doc_ids.include?(@doc.id)).to eq(true)

      #and user has permission to read it
      has_perm = PermissionService.has_permission(:read, @user, @company, @doc)
      expect(has_perm).to eq(true)
    end

    it "User can see to be approve documents if these are not restricted and accountable for user (not approved for user's area)" do
      u_comp = @user.user_company(@company)
      u_comp.company_path_ids = @doc.belongs_to_paths.first
      u_comp.save
      @user.reload

      new_docs = @user.docs(@company, "all")

      new_doc_ids = new_docs[:docs].pluck(:id)
      expect(new_doc_ids.include?(@doc.id)).to eq(true)

      #and user has permission to read it
      has_perm = PermissionService.has_permission(:read, @user, @company, @doc)
      expect(has_perm).to eq(true)
    end

    it "User can see to be approve documents if these are restricted but for user's area and accountable for user (not approved for user's area)" do
      u_comp = @user.user_company(@company)
      u_comp.company_path_ids = @doc.belongs_to_paths.first
      u_comp.save
      @user.reload

      @doc.restricted = true
      @doc.save

      new_docs = @user.docs(@company, "all")

      new_doc_ids = new_docs[:docs].pluck(:id)
      expect(new_doc_ids.include?(@doc.id)).to eq(true)

      #and user has permission to read it
      has_perm = PermissionService.has_permission(:read, @user, @company, @doc)
      expect(has_perm).to eq(true)
    end

    it "User can not see to be approve documents if these are restricted but not restricted for user's area" do
      u_comp = @user.user_company(@company)
      u_comp.company_path_ids = (@all_paths.keys - @doc.belongs_to_paths).first
      u_comp.save
      @user.reload

      @doc.restricted = true
      @doc.save

      new_docs = @user.docs(@company, "all")

      new_doc_ids = new_docs[:docs].pluck(:id)
      expect(new_doc_ids.include?(@doc.id)).to eq(false)

      #and user has no permission to read it
      has_perm = PermissionService.has_permission(:read, @user, @company, @doc)
      expect(has_perm).to eq(false)
    end
  end
end