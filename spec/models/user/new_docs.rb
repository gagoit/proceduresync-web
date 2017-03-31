require 'spec_helper'

describe "User: new_docs:" do
  
  context "for Standard Company:" do
    context "sync_all:" do
      before(:each) do
        create_default_data({company_type: :standard})
      end

      it "when user is admin || super_help_desk_user, user will see all company docs" do
        new_docs = @admin.new_docs(@company)

        expect(new_docs.count).to eq(@company.documents.count)
      end

      it "when user is not belong to company or any parts of company, user will see no docs" do
        new_user = create :user, token: "#{@user.token}1", admin: false

        new_docs = new_user.new_docs(@company)

        expect(new_docs.count).to eq(0)
      end

      it "when user is assigned to part of org that has no doc, user will see no docs" do
        u_comp = assign_user_to_path(@user, @company, {
          company_path_ids: (@all_paths.keys - @doc.belongs_to_paths - @doc1.belongs_to_paths).first
        })

        new_docs = @user.new_docs(@company)

        expect(new_docs.count).to eq(0)
      end

      it "when user is assigned to part of org that has one doc, user will see one doc" do
        u_comp = assign_user_to_path(@user, @company, {
          company_path_ids: @doc.belongs_to_paths.first
        })
        @user.reload

        new_docs = @user.new_docs(@company)

        expect(new_docs.count).to eq(1)
        expect(new_docs.first.id).to eq(@doc.id)
      end

      it "when user is assigned to part of org that has two docs, user will see two docs" do
        u_comp = assign_user_to_path(@user, @company, {
          company_path_ids: @doc.belongs_to_paths.first
        })
        @user.reload

        @doc1.belongs_to_paths << u_comp.company_path_ids
        @doc1.save

        new_docs = @user.new_docs(@company)

        expect(new_docs.count).to eq(2)
      end

      it "when user is assigned to part of org that has two docs, and also have a private doc, user will see three docs" do
        u_comp = assign_user_to_path(@user, @company, {
          company_path_ids: @doc.belongs_to_paths.first
        })
        @user.reload

        @doc1.belongs_to_paths << u_comp.company_path_ids
        @doc1.save

        private_doc, private_version = create_private_doc(@user, @company)

        new_docs = @user.new_docs(@company)

        expect(new_docs.count).to eq(3)

        ids = new_docs.pluck(:id)
        expect(ids.include?(private_doc.id)).to eq(true)
        expect(ids.include?(@doc.id)).to eq(true)
        expect(ids.include?(@doc1.id)).to eq(true)
      end

      it "when user is assigned to part of org that has two docs, one of them is restricted for user's area, user will see two docs" do
        u_comp = assign_user_to_path(@user, @company, {
          company_path_ids: @doc.belongs_to_paths.first
        })
        @user.reload

        @doc1.belongs_to_paths << u_comp.company_path_ids
        @doc1.restricted = true
        @doc1.restricted_paths = [u_comp.company_path_ids]
        @doc1.save

        new_docs = @user.new_docs(@company)

        expect(new_docs.count).to eq(2)

        ids = new_docs.pluck(:id)
        expect(ids.include?(@doc.id)).to eq(true)
        expect(ids.include?(@doc1.id)).to eq(true)
      end

      it "when user is assigned to part of org that has two docs, one of them is restricted but not for user's area, user will see two docs" do
        u_comp = assign_user_to_path(@user, @company, {
          company_path_ids: @doc.belongs_to_paths.first
        })
        @user.reload

        @doc1.belongs_to_paths << u_comp.company_path_ids
        @doc1.restricted = true
        @doc1.restricted_paths = @all_paths.keys - [u_comp.company_path_ids]
        @doc1.save

        new_docs = @user.new_docs(@company)

        expect(new_docs.count).to eq(2)

        ids = new_docs.pluck(:id)
        expect(ids.include?(@doc.id)).to eq(true)
        expect(ids.include?(@doc1.id)).to eq(true)
      end
    end

    context "use after_timestamp:" do
      before(:each) do
        create_default_data({company_type: :standard})
      end

      it "when user is not belong to company or any parts of company, user will see no docs" do
        new_user = create :user, token: "#{@user.token}1", admin: false

        new_docs = new_user.new_docs(@company, {after_timestamp: Time.now.utc.to_s})

        expect(new_docs.count).to eq(0)
      end

      it "when assign in part of org that has no doc" do
        u_comp = assign_user_to_path(@user, @company, {
          company_path_ids: (@all_paths.keys - @doc.belongs_to_paths - @doc1.belongs_to_paths).first
        })

        new_docs = @user.new_docs(@company, {after_timestamp: Time.now.utc.to_s})

        expect(new_docs.count).to eq(0)
      end

      it "when assign in part of org that has one doc, but already synced" do
        u_comp = assign_user_to_path(@user, @company, {
          company_path_ids: @doc.belongs_to_paths.first
        })
        @user.reload

        sleep 5

        new_docs = @user.new_docs(@company, {after_timestamp: Time.now.utc.to_s})

        expect(new_docs.count).to eq(0)
      end

      it "when assign in part of org that has one doc" do
        sleep 2
        time = Time.now.utc.to_s
        sleep 2

        u_comp = assign_user_to_path(@user, @company, {
          company_path_ids: @doc.belongs_to_paths.first
        })
        @user.reload
        UserService.update_user_documents({user: @user, company: @company})

        new_docs = @user.new_docs(@company, {after_timestamp: time})

        expect(new_docs.count).to eq(1)
        expect(new_docs.first.id).to eq(@doc.id)
      end

      it "when assign in part of org that has two docs, but one doc is synced" do
        u_comp = assign_user_to_path(@user, @company, {
          company_path_ids: @doc.belongs_to_paths.first
        })
        @user.reload

        sleep 2
        time = Time.now.utc.to_s
        sleep 2
        UserService.update_user_documents({document: @doc, company: @company})

        @doc1.belongs_to_paths << u_comp.company_path_ids
        @doc1.save

        new_docs = @user.new_docs(@company, {after_timestamp: time})

        expect(new_docs.count).to eq(1)
      end

      it "when assign in part of org that has two docs, and have a private doc, but 2 docs are synced before" do
        u_comp = assign_user_to_path(@user, @company, {
          company_path_ids: @doc.belongs_to_paths.first
        })
        @user.reload
        UserService.update_user_documents({user: @user, company: @company})

        @doc1.belongs_to_paths << u_comp.company_path_ids
        @doc1.save
        UserService.update_user_documents({document: @doc1, company: @company})

        sleep 2
        time = Time.now.utc.to_s
        sleep 2

        private_doc, private_version = create_private_doc(@user, @company)
        UserService.update_user_documents({document: private_doc, company: @company})

        new_docs = @user.new_docs(@company, {after_timestamp: time})

        expect(new_docs.count).to eq(1)

        ids = new_docs.pluck(:id)
        expect(ids.include?(private_doc.id)).to eq(true)
      end
    end
  end

  context "there are non-accountable docs that is/are favourite:" do
    context "sync_all" do
      before(:each) do
        create_default_data({company_type: :standard})
      end

      it "when user is belongs to a path that don't have any document, but there is a non-accountable doc that is favourite, user will see one doc" do
        u_comp = assign_user_to_path(@user, @company, {
          company_path_ids: (@all_paths.keys - @doc.belongs_to_paths - @doc1.belongs_to_paths).first
        })
        @user.reload

        @user.favour_document!(@doc)

        new_docs = @user.new_docs(@company)

        expect(new_docs.count).to eq(1)
        expect(new_docs.first.id).to eq(@doc.id)
      end

      it "when assign in part of org that has no doc, but there is a non-accountable doc that is favourite" do
        u_comp = assign_user_to_path(@user, @company, {
          company_path_ids: (@all_paths.keys - @doc.belongs_to_paths - @doc1.belongs_to_paths).first
        })
        @user.reload

        @user.favour_document!(@doc)

        new_docs = @user.new_docs(@company)

        expect(new_docs.count).to eq(1)
        expect(new_docs.first.id).to eq(@doc.id)
      end

      it "when assign in part of org that has one doc, and there is a non-accountable doc that is favourite" do
        u_comp = assign_user_to_path(@user, @company, {
          company_path_ids: @doc.belongs_to_paths.first
        })
        @user.reload

        @user.favour_document!(@doc1)

        new_docs = @user.new_docs(@company)

        expect(new_docs.count).to eq(2)

        new_doc_ids = new_docs.pluck(:id)
        expect(new_doc_ids.include?(@doc1.id)).to eq(true)
        expect(new_doc_ids.include?(@doc.id)).to eq(true)
      end

      it "when assign in part of org that has two docs, and there is no non-accountable doc that is favourite" do
        u_comp = assign_user_to_path(@user, @company, {
          company_path_ids: @doc.belongs_to_paths.first
        })
        @user.reload

        @doc1.belongs_to_paths -= [u_comp.company_path_ids]
        @doc1.save

        @user.favour_document!(@doc1)

        new_docs = @user.new_docs(@company)
        new_doc_ids = new_docs.pluck(:id)

        expect(new_docs.count).to eq(2)
        expect(new_doc_ids.include?(@doc1.id)).to eq(true)
        expect(new_doc_ids.include?(@doc.id)).to eq(true)
      end

      it "when assign in part of org that has two docs, and have a private doc, and private doc is favourite" do
        u_comp = assign_user_to_path(@user, @company, {
          company_path_ids: @doc.belongs_to_paths.first
        })
        @user.reload

        @doc1.belongs_to_paths << u_comp.company_path_ids
        @doc1.save

        private_doc, private_version = create_private_doc(@user, @company)

        @user.favour_document!(private_doc)

        new_docs = @user.new_docs(@company)

        expect(new_docs.count).to eq(3)

        ids = new_docs.pluck(:id)
        expect(ids.include?(private_doc.id)).to eq(true)
        expect(ids.include?(@doc.id)).to eq(true)
        expect(ids.include?(@doc1.id)).to eq(true)
      end

      it "when user is assigned to part of org that has one doc, and have a non-accountable document that is restricted for user's area but favourite, user will see one doc" do
        u_comp = assign_user_to_path(@user, @company, {
          company_path_ids: @doc.belongs_to_paths.first
        })
        @user.reload

        @doc1.belongs_to_paths -= [u_comp.company_path_ids]
        @doc1.restricted = true
        @doc1.restricted_paths = [u_comp.company_path_ids]
        @doc1.save

        @user.favour_document!(@doc1)

        new_docs = @user.new_docs(@company)

        expect(new_docs.count).to eq(1)

        ids = new_docs.pluck(:id)
        expect(ids.include?(@doc.id)).to eq(true)
        expect(ids.include?(@doc1.id)).to eq(false)
      end
    end

    context "use after_timestamp:" do
      before(:each) do
        create_default_data({company_type: :standard})
      end

      it "when user is not belong to company or any parts of company, but there is a non-accountable doc that is favourite" do
        u_comp = assign_user_to_path(@user, @company, {
          company_path_ids: (@all_paths.keys - @doc.belongs_to_paths - @doc1.belongs_to_paths).first
        })
        @user.reload

        sleep 2
        time = Time.now.utc.to_s
        sleep 2

        @user.favour_document!(@doc)

        new_docs = @user.new_docs(@company, {after_timestamp: time})

        expect(new_docs.count).to eq(1)
        expect(new_docs.first.id).to eq(@doc.id)
      end

      it "when assign in part of org that has no doc, but there is a non-accountable doc that is favourite" do
        u_comp = assign_user_to_path(@user, @company, {
          company_path_ids: (@all_paths.keys - @doc.belongs_to_paths - @doc1.belongs_to_paths).first
        })
        @user.reload

        sleep 2
        time = Time.now.utc.to_s
        sleep 2

        @user.favour_document!(@doc)

        new_docs = @user.new_docs(@company, {after_timestamp: time})

        expect(new_docs.count).to eq(1)
        expect(new_docs.first.id).to eq(@doc.id)
      end

      it "when assign in part of org that has one doc that is already synced before, and there is a non-accountable doc that is favourite and never synced" do
        u_comp = assign_user_to_path(@user, @company, {
          company_path_ids: @doc.belongs_to_paths.first
        })
        @user.reload

        sleep 2
        time = Time.now.utc.to_s
        sleep 2

        @doc1.belongs_to_paths -= [u_comp.company_path_ids]
        @doc1.save

        @user.favour_document!(@doc1)

        new_docs = @user.new_docs(@company, {after_timestamp: time})

        expect(new_docs.count).to eq(1)
        expect(new_docs.first.id).to eq(@doc1.id)
      end

      it "when assign in part of org that has one doc, and there is a non-accountable doc that is favourite" do
        sleep 2
        time = Time.now.utc.to_s
        sleep 2

        u_comp = assign_user_to_path(@user, @company, {
          company_path_ids: @doc.belongs_to_paths.first
        })
        @user.reload
        UserService.update_user_documents({user: @user, company: @company})

        @user.favour_document!(@doc1)
        UserService.update_user_documents({user: @user, company: @company, document: @doc1})

        new_docs = @user.new_docs(@company, {after_timestamp: time})

        expect(new_docs.count).to eq(2)

        new_doc_ids = new_docs.pluck(:id)
        expect(new_doc_ids.include?(@doc.id)).to eq(true)
        expect(new_doc_ids.include?(@doc1.id)).to eq(true)
      end

      it "when assign in part of org that has two docs, but one doc is already synced before, and there is a non-accountable doc that is favourite and never synced" do
        u_comp = assign_user_to_path(@user, @company, {
          company_path_ids: @doc.belongs_to_paths.first
        })
        @user.reload
        UserService.update_user_documents({user: @user, company: @company})

        sleep 2
        time = Time.now.utc.to_s
        sleep 2

        non_accountable_doc = create :document, category_id: @category.id, company_id: @company.id, belongs_to_paths: (@all_paths.keys - [u_comp.company_path_ids])
        non_accountable_doc_version = create :version, document_id: non_accountable_doc.id, box_status: "done", box_file_size: 100

        non_accountable_doc.curr_version = "1.0"
        non_accountable_doc.save
        @user.favour_document!(non_accountable_doc)
        UserService.update_user_documents({user: @user, company: @company, document: non_accountable_doc})

        @doc1.belongs_to_paths << u_comp.company_path_ids
        @doc1.save
        UserService.update_user_documents({document: @doc1, company: @company})
        @user.reload

        new_docs = @user.new_docs(@company, {after_timestamp: time})
        new_doc_ids = new_docs.pluck(:id)

        expect(new_docs.count).to eq(2)
        expect(new_doc_ids.include?(non_accountable_doc.id)).to eq(true)
        expect(new_doc_ids.include?(@doc1.id)).to eq(true)
      end

    end
  end
end