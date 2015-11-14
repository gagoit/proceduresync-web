require 'spec_helper'

describe "Notification" do
  
  describe "when_doc_is_assign:" do
    context "When user has been changed area in company" do
      before(:each) do
        create_default_data({company_type: :standard})
      end

      it "create notification for accountable users at the first time, with unread status" do
        u_comp = @user.user_company(@company)
        u_comp.company_path_ids = @doc.belongs_to_paths.first
        u_comp.save

        @user.reload
        @doc.reload

        noti = @user.get_notifications(@company).where(document_id: @doc.id, type: Notification::TYPES[:unread_document][:code]).first

        expect(noti).to_not eq(nil)
        expect(noti.status).to eq(Notification::UNREAD_STATUS)
      end
    end

    context "When document has been changed: new version/file" do
      before(:each) do
        create_default_data({company_type: :standard})
      end

      it "create/update all notifications of accountable users with unread status" do
        u_comp = @user.user_company(@company)
        u_comp.company_path_ids = @doc.belongs_to_paths.first
        u_comp.save

        @user.reload
        @doc.reload

        noti = @user.get_notifications(@company).where(document_id: @doc.id, type: Notification::TYPES[:unread_document][:code]).first

        expect(noti).to_not eq(nil)
        expect(noti.status).to eq(Notification::UNREAD_STATUS)

        @user.get_notifications(@company).update_all(status: Notification::READ_STATUS)

        @doc.curr_version = "1.1111"
        @doc.save

        @user.reload
        @doc.reload

        noti1 = @user.get_notifications(@company).where(document_id: @doc.id, type: Notification::TYPES[:unread_document][:code]).first

        expect(noti1).to_not eq(nil)
        expect(noti.id).to eq(noti1.id)
        expect(noti1.status).to eq(Notification::UNREAD_STATUS)        
      end
    end


    context "When document has been changed: added new paths" do
      before(:each) do
        create_default_data({company_type: :standard})
      end

      it "if user already read notification, we will update notification with new created_at, keep the read status" do
        u_comp = @user.user_company(@company)
        u_comp.company_path_ids = @doc.belongs_to_paths.first
        u_comp.save

        @user.reload
        @doc.reload

        noti = @user.get_notifications(@company).where(document_id: @doc.id, type: Notification::TYPES[:unread_document][:code]).first

        expect(noti).to_not eq(nil)
        expect(noti.status).to eq(Notification::UNREAD_STATUS)

        @user.get_notifications(@company).update_all(status: Notification::READ_STATUS)

        #other user
        new_user = create :user, token: "#{@admin.token}113", company_ids: [@company.id], admin: false
        new_user.reload
        @company.reload
        User.update_companies_of_user(new_user, [], [@company.id])
        new_user.reload

        new_u_comp = new_user.user_company(@company)
        new_u_comp.company_path_ids = (@all_paths.keys - @doc.belongs_to_paths).first
        new_u_comp.save

        @doc.belongs_to_paths << new_u_comp.company_path_ids
        @doc.save

        @user.reload
        @doc.reload

        noti1 = @user.get_notifications(@company).where(document_id: @doc.id, type: Notification::TYPES[:unread_document][:code]).first
        expect(noti1).to_not eq(nil)
        expect(noti.id).to eq(noti1.id)
        expect(noti1.status).to eq(Notification::READ_STATUS)        

        noti2 = new_user.get_notifications(@company).where(document_id: @doc.id, type: Notification::TYPES[:unread_document][:code]).first
        expect(noti2).to_not eq(nil)
        expect(noti2.status).to eq(Notification::UNREAD_STATUS)
      end
    end

    context "When document has been changed:" do
      before(:each) do
        create_default_data({company_type: :standard})
      end

      it "When change version, create notification with unread status for all accountable users" do
        u_comp = @user.user_company(@company)
        u_comp.company_path_ids = @doc.belongs_to_paths.first
        u_comp.save

        @user.reload
        @doc.reload

        noti = @user.get_notifications(@company).where(document_id: @doc.id, type: Notification::TYPES[:unread_document][:code]).first

        expect(noti).to_not eq(nil)
        expect(noti.status).to eq(Notification::UNREAD_STATUS)

        @user.get_notifications(@company).update_all(status: Notification::READ_STATUS)

        @doc.curr_version = "#{@doc.curr_version}.0"
        @doc.save

        @user.reload
        @doc.reload

        noti1 = @user.get_notifications(@company).where(document_id: @doc.id, type: Notification::TYPES[:unread_document][:code]).first
        expect(noti1).to_not eq(nil)
        expect(noti.id).to eq(noti1.id)
        expect(noti1.status).to eq(Notification::UNREAD_STATUS)
      end

      it "When added new file, create notification with unread status for all accountable users" do
        u_comp = @user.user_company(@company)
        u_comp.company_path_ids = @doc.belongs_to_paths.first
        u_comp.save

        @user.reload
        @doc.reload

        noti = @user.get_notifications(@company).where(document_id: @doc.id, type: Notification::TYPES[:unread_document][:code]).first

        expect(noti).to_not eq(nil)
        expect(noti.status).to eq(Notification::UNREAD_STATUS)

        @user.get_notifications(@company).update_all(status: Notification::READ_STATUS)

        version = @doc.current_version
        version.doc_file = "#{version.doc_file}1"
        version.save

        @user.reload
        @doc.reload

        noti1 = @user.get_notifications(@company).where(document_id: @doc.id, type: Notification::TYPES[:unread_document][:code]).first
        expect(noti1).to_not eq(nil)
        expect(noti.id).to eq(noti1.id)
        expect(noti1.status).to eq(Notification::UNREAD_STATUS)
      end
    end
  end

  describe "sent_daily_approval_email:" do
    context "When user is approver and has not approve document" do
      before(:each) do
        create_default_data({company_type: :advanced})
      end

      it "if user set approval email settings is daily email, we will check and has one email for user" do
        assign_permission(@user, @company, Permission::STANDARD_PERMISSIONS[:approver_user][:code])
        @user.reload

        u_comp = @user.user_company(@company)
        u_comp.company_path_ids = @doc.belongs_to_paths.first
        u_comp.approver_path_ids = @doc.belongs_to_paths
        u_comp.approval_email_settings = UserCompany::APPROVAL_EMAIL_SETTINGS[:email_daily]
        u_comp.save

        @user.reload
        @doc.reload

        num_emails = Notification.sent_daily_approval_email

        expect(num_emails).to eq(1)
      end

      it "if user set approval email settings is not daily email, we will check and has no email for user" do
        assign_permission(@user, @company, Permission::STANDARD_PERMISSIONS[:approver_user][:code])
        @user.reload

        u_comp = @user.user_company(@company)
        u_comp.company_path_ids = @doc.belongs_to_paths.first
        u_comp.approver_path_ids = @doc.belongs_to_paths
        u_comp.approval_email_settings = UserCompany::APPROVAL_EMAIL_SETTINGS[:no_email]
        u_comp.save

        @user.reload
        @doc.reload

        num_emails = Notification.sent_daily_approval_email

        expect(num_emails).to eq(0)
      end
    end

    context "When user is approver and has already approve document" do
      before(:each) do
        create_default_data({company_type: :advanced})
      end

      it "if user set approval email settings is daily email, we will check and has no email for user" do
        assign_permission(@user, @company, Permission::STANDARD_PERMISSIONS[:approver_user][:code])
        @user.reload

        u_comp = @user.user_company(@company)
        u_comp.company_path_ids = @doc.belongs_to_paths.first
        u_comp.approver_path_ids = @doc.belongs_to_paths
        u_comp.approval_email_settings = UserCompany::APPROVAL_EMAIL_SETTINGS[:email_daily]
        u_comp.save

        @user.reload
        @doc.reload

        @doc.approve!(@user, @company, {}, {document: {approve_document_to: "approve_all"}})

        num_emails = Notification.sent_daily_approval_email

        expect(num_emails).to eq(0)
      end
    end
  end
end