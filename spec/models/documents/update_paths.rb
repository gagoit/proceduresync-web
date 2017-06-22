require 'spec_helper'

describe "Document: update_paths:" do
  context "Who can do bulk assignment" do
    before(:each) do
      create_default_data({company_type: :advanced})

      @params = {ids: "all", paths: [].to_s, search: "", filter: "all", filter_category_id: nil, document_types: "all", 
        assignment_type: "add_accountability"
      }
    end

    it "Super Admin and Super help desk user can do" do
      result = Document.update_paths(@admin, @company, @params)

      expect(result[:success]).to eq(true)
    end

    it "Users have add/edit document permission can do" do
      u_comp = assign_user_to_path(@user, @company, {company_path_ids: @doc.belongs_to_paths.first})
      assign_permission(@user, @company, Permission::STANDARD_PERMISSIONS[:approver_user][:code])

      u_comp_permission = @user.comp_permission(@company)
      u_comp_permission.add_edit_documents = true
      u_comp_permission.bulk_assign_documents = false
      u_comp_permission.save

      @user.reload
      @company.reload

      result = Document.update_paths(@user, @company, @params)

      expect(result[:success]).to eq(true)
    end

    it "Users have Approver permission and bulk assignment permission can do" do
      u_comp = assign_user_to_path(@user, @company, {company_path_ids: @doc.belongs_to_paths.first})
      assign_permission(@user, @company, Permission::STANDARD_PERMISSIONS[:approver_user][:code])
      
      u_comp_permission = @user.comp_permission(@company)
      u_comp_permission.add_edit_documents = false
      u_comp_permission.bulk_assign_documents = true
      u_comp_permission.save

      @user.reload
      @company.reload

      result = Document.update_paths(@user, @company, @params)

      expect(result[:success]).to eq(true)
    end

    it "Users is not in above types can not do" do
      u_comp = assign_user_to_path(@user, @company, {company_path_ids: @doc.belongs_to_paths.first})
      assign_permission(@user, @company, Permission::STANDARD_PERMISSIONS[:supervisor_user][:code])
      
      u_comp_permission = @user.comp_permission(@company)
      u_comp_permission.add_edit_documents = false
      u_comp_permission.bulk_assign_documents = false
      u_comp_permission.save

      @user.reload
      @company.reload

      result = Document.update_paths(@user, @company, @params)

      expect(result[:success]).to eq(false)
      expect(result[:message]).to eq(I18n.t("error.access_denied"))
    end
  end

  context "assignment_type add_accountability:" do
    before(:each) do
      create_default_data({company_type: :advanced})

      #user has add/edit document permission
      u_comp = assign_user_to_path(@user, @company, {company_path_ids: @doc.belongs_to_paths.first})
      
      u_comp_permission = @user.comp_permission(@company)
      u_comp_permission.add_edit_documents = true
      u_comp_permission.bulk_assign_documents = false
      u_comp_permission.save

      @user.reload
      @company.reload

      @params = {ids: "all", paths: [].to_s, search: "", filter: "all", filter_category_id: nil, document_types: "all", 
        assignment_type: "add_accountability"
      }
    end

    context "when we add accountability to document, these areas will be accountable for users in added areas( don't need to be approve ):" do
      it "in case these areas are not accountable before" do
        new_paths = (@all_paths.keys - @doc.belongs_to_paths)
        @params[:ids] = [@doc.id.to_s]
        @params[:paths] = new_paths.to_s

        result = Document.update_paths(@user, @company, @params)

        @doc.reload

        new_paths.each do |area|
          expect(@doc.approved_paths.include?(area)).to eq(true)
        end

        expect(result[:success]).to eq(true)
        expect(result[:message]).to eq("Documents have been updated successfully")
      end

      it "in case these areas are not not approved before" do
        @doc.approved_paths = []
        @doc.save

        @params[:ids] = [@doc.id.to_s]
        @params[:paths] = @all_paths.keys.to_s

        result = Document.update_paths(@user, @company, @params)

        @doc.reload

        @all_paths.keys.each do |area|
          expect(@doc.approved_paths.include?(area)).to eq(true)
        end

        expect(result[:success]).to eq(true)
        expect(result[:message]).to eq("Documents have been updated successfully")
      end

      it "and we will update user_documents relationship users're in new areas with accountable = true" do
        @doc.approved_paths = []
        @doc.save

        @params[:ids] = [@doc.id.to_s]
        @params[:paths] = @all_paths.keys.to_s

        user1, u1_comp = create_user(@company, {info: {}, paths: {company_path_ids: @all_paths.keys.last}})

        result = Document.update_paths(@user, @company, @params)

        @doc.reload

        @all_paths.keys.each do |area|
          expect(@doc.approved_paths.include?(area)).to eq(true)
        end

        #in test mode, it's not run the delayed job, so we will run it manually
        # UserService.update_user_documents({document: @doc, company: @company})
        DocumentService.add_accountable_to_paths(@company, @doc, @all_paths.keys)
        # WebNotification.create_from_document(
        #   @doc, 
        #   {
        #     new_version: false,
        #     new_avai_user_ids: [@user.id, user1.id]
        #   }
        # )
        u_ids = @doc.company_users(@company).pluck(:user_id)
        expect(u_ids.include?(@user.id)).to eq(true)
        expect(u_ids.include?(user1.id)).to eq(true)

        expect(result[:success]).to eq(true)
        expect(result[:message]).to eq("Documents have been updated successfully")
      end
    end
  end

  context "assignment_type remove_accountability:" do
    before(:each) do
      create_default_data({company_type: :advanced})

      #user has add/edit document permission
      u_comp = assign_user_to_path(@user, @company, {company_path_ids: @doc.belongs_to_paths.first})

      u_comp_permission = @user.comp_permission(@company)
      u_comp_permission.add_edit_documents = true
      u_comp_permission.bulk_assign_documents = false
      u_comp_permission.save

      @user.reload
      @company.reload

      @params = {ids: "all", paths: [].to_s, search: "", filter: "all", filter_category_id: nil, document_types: "all", 
        assignment_type: "remove_accountability"
      }
    end

    it "Document is already accountable -> Remove accountability:" do
      @doc.approved_paths = @doc.belongs_to_paths
      @doc.save

      new_paths = @doc.belongs_to_paths
      @params[:ids] = [@doc.id.to_s]
      @params[:paths] = new_paths.to_s

      result = Document.update_paths(@user, @company, @params)

      @doc.reload

      new_paths.each do |area|
        expect(@doc.belongs_to_paths.include?(area)).to eq(false)
      end

      expect(result[:success]).to eq(true)
      expect(result[:message]).to eq("Documents have been updated successfully")
    end 

    it "Document is Accountable but not approved -> Remove accountability:" do
      new_paths = @doc.belongs_to_paths
      @params[:ids] = [@doc.id.to_s]
      @params[:paths] = new_paths.to_s

      result = Document.update_paths(@user, @company, @params)

      @doc.reload

      new_paths.each do |area|
        expect(@doc.belongs_to_paths.include?(area)).to eq(false)
      end

      expect(result[:success]).to eq(true)
      expect(result[:message]).to eq("Documents have been updated successfully")
    end

    it "and we will update user_documents relationship users're in new areas with accountable = false" do
      @doc.approved_paths = @doc.belongs_to_paths
      @doc.save
      UserService.update_user_documents({document: @doc.reload, company: @company})

      new_paths = @doc.belongs_to_paths
      @params[:ids] = [@doc.id.to_s]
      @params[:paths] = new_paths.to_s

      result = Document.update_paths(@user, @company, @params)

      @doc.reload

      new_paths.each do |area|
        expect(@doc.belongs_to_paths.include?(area)).to eq(false)
      end

      #in test mode, it's not run the delayed job, so we will run it manually
      # UserService.update_user_documents({document: @doc, company: @company})
      DocumentService.remove_accountability_of_paths(@company, @doc, new_paths)

      u_doc = @doc.company_users(@company).where(user_id: @user.id).first
      expect(u_doc.present?).to eq(true)
      expect(u_doc.is_accountable).to eq(false)

      expect(result[:success]).to eq(true)
      expect(result[:message]).to eq("Documents have been updated successfully")
    end
  end

  context "Check UNREAD document notification:" do
    before(:each) do
      create_default_data({company_type: :advanced})

      #user has add/edit document permission
      u_comp = assign_user_to_path(@user, @company, {company_path_ids: @doc.belongs_to_paths.first})
      
      u_comp_permission = @user.comp_permission(@company)
      u_comp_permission.add_edit_documents = true
      u_comp_permission.bulk_assign_documents = false
      u_comp_permission.save

      @user.reload
      @company.reload

      @params = {ids: "all", paths: [].to_s, search: "", filter: "all", filter_category_id: nil, document_types: "all", 
        assignment_type: "add_accountability"
      }
    end

    # it "when add_accountability, users who have not read this document before will see UNREAD document notification:" do
    #   new_paths = @doc.belongs_to_paths
    #   @params[:ids] = [@doc.id.to_s]
    #   @params[:paths] = new_paths.to_s

    #   result = Document.update_paths(@user, @company, @params)

    #   @doc.reload
    #   @user.reload

    #   #in test mode, it's not run the delayed job, so we will run it manually
    #   UserService.update_user_documents({document: @doc, company: @company})

    #   expect(@doc.available_for_user_ids.include?(@user.id)).to eq(true)

    #   unread_doc_notifications = @user.get_notifications(@company).where(type: Notification::TYPES[:unread_document][:code])

    #   doc_ids = unread_doc_notifications.pluck(:document_id)

    #   expect(doc_ids.include?(@doc.id)).to eq(true)
    # end

    it "when add_accountability, users who have read this document before will not see UNREAD document notification:" do
      new_paths = @doc.belongs_to_paths
      @params[:ids] = [@doc.id.to_s]
      @params[:paths] = new_paths.to_s

      @user.read_document!(@doc)

      result = Document.update_paths(@user, @company, @params)

      @doc.reload
      @user.reload

      #in test mode, it's not run the delayed job, so we will run it manually
      # UserService.update_user_documents({document: @doc, company: @company})
      DocumentService.add_accountable_to_paths(@company, @doc, new_paths)

      unread_doc_notifications = @user.get_notifications(@company).where(type: Notification::TYPES[:unread_document][:code])

      doc_ids = unread_doc_notifications.pluck(:document_id)

      expect(doc_ids.include?(@doc.id)).to eq(false)
    end

    #If a document is assigned for approval and is approved by approver and the accountability is then removed (through action drop down) 
    #(without the standard user who was accountable for the doc reading the doc) and then accountability is added again. 
    #It never shows up as “unread” for the users in that section again even though they never read it the first time.
    it "document is assigned for approval and is approved by approver and the accountability is then removed, and then accountability is added again. users who have not read this document before will see UNREAD document notification:" do
      @doc.approved_paths = @doc.belongs_to_paths
      @doc.save

      new_paths = @doc.belongs_to_paths
      @params[:ids] = [@doc.id.to_s]
      @params[:paths] = new_paths.to_s
      @params[:assignment_type] = "remove_accountability"

      #remove accountability
      result = Document.update_paths(@user, @company, @params)

      @doc.reload
      @user.reload
      expect(@doc.available_for_user_ids.include?(@user.id)).to eq(false)

      #add accountability again
      @params[:assignment_type] = "add_accountability"
      result = Document.update_paths(@user, @company, @params)

      @doc.reload
      @user.reload

      #in test mode, it's not run the delayed job, so we will run it manually
      # UserService.update_user_documents({document: @doc, company: @company})
      DocumentService.add_accountable_to_paths(@company, @doc, new_paths)
      WebNotification.create_from_document(
        @doc, 
        {
          new_version: false,
          new_avai_user_ids: [@user.id]
        }
      )

      expect(@doc.available_for_user_ids.include?(@user.id)).to eq(true)

      unread_doc_notifications = @user.get_notifications(@company).where(type: Notification::TYPES[:unread_document][:code])

      doc_ids = unread_doc_notifications.pluck(:document_id)

      expect(doc_ids.include?(@doc.id)).to eq(true)
    end
  end
end