require 'spec_helper'

describe "User" do
  describe "validates" do
    context "ok" do
      before(:each) do
        User.destroy_all
        user_temp = build :user, token: User.access_token
        @user_hash = user_temp.attributes.except("id", "created_at", "updated_at")
      end

      it "success" do
        user = User.create(@user_hash)

        expect(user.errors.blank?).to eq(true)
      end

      it "token is auto created" do
        @user_hash.delete("token")
        user = User.create(@user_hash)

        expect(user.valid?).to eq(true)
        expect(user.token).to_not eq(nil)
      end
    end

    context "Error" do
      before(:each) do
        user_temp = build :user, token: User.access_token
        @user_hash = user_temp.attributes.except("id", "created_at", "updated_at")
      end

      it "name is required" do
        @user_hash.delete("name")
        user = User.create(@user_hash)

        expect(user.errors.include?(:name)).to eq(true)
      end

      it "email is required" do
        @user_hash.delete("email")
        user = User.create(@user_hash)

        expect(user.errors.include?(:email)).to eq(true)
      end
    end
  end

  describe "has_setup" do
    context "ok" do
      before(:each) do
        User.destroy_all
        user_temp = build :user, token: User.access_token
        @user_hash = user_temp.attributes.except("id", "created_at", "updated_at")
      end

      it "edit home_email" do
        user = User.create(@user_hash)
        expect(user.has_setup).to eq(false)
        user.reload

        user.home_email = "newemail@gmail.com"
        user.save
        user.reload

        expect(user.has_setup).to eq(true)
      end

      it "edit home_email" do
        user = User.create(@user_hash)
        expect(user.has_setup).to eq(false)
        user.reload

        user.password = "newpassword"
        user.save
        user.reload

        expect(user.has_setup).to eq(true)
      end
    end
  end

  

  describe "remove_invalid_docs" do
    context "ok" do
      before(:each) do
        create_default_data

        @all_paths = @company.all_paths_hash

        u_comp = @user.user_company(@company)
        u_comp.company_path_ids = @all_paths.keys.first
        u_comp.save

        @all_paths.keys.each do |e|
          if e.index(u_comp.company_path_ids).nil?
            @doc.belongs_to_paths = [e]
            @doc.save
            break
          end
        end
      end

      it "remove one doc in all lists" do
        @user.favour_document!(@doc)
        @user.read_document!(@doc)

        expect(@user.favourite_document_ids.length).to eq(1)
        expect(@user.read_document_ids.length).to eq(1)

        @user.remove_invalid_docs([@doc.id])
        @user.reload

        expect(@user.favourite_document_ids.length).to eq(0)
        expect(@user.read_document_ids.length).to eq(0)
      end

      it "remove one doc in list favourite" do
        @user.favour_document!(@doc)
        @user.read_document!(@doc)

        expect(@user.favourite_document_ids.length).to eq(1)
        expect(@user.read_document_ids.length).to eq(1)

        @user.remove_invalid_docs([@doc.id], [:favourite])
        @user.reload

        expect(@user.favourite_document_ids.length).to eq(0)
        expect(@user.read_document_ids.length).to eq(1)
      end

      # it "remove one doc in list private" do
      #   @user.favour_document!(@doc)
      #   @user.read_document!(@doc)

      #   @doc.is_private = true
      #   @doc.private_for_id = @user.id
      #   @doc.save

      #   expect(@user.favourite_document_ids.length).to eq(1)
      #   expect(@user.read_document_ids.length).to eq(1)
      #   expect(@user.private_document_ids.length).to eq(1)

      #   @user.remove_invalid_docs([@doc.id], [:private])
      #   @user.reload

      #   expect(@user.favourite_document_ids.length).to eq(1)
      #   expect(@user.read_document_ids.length).to eq(1)
      #   expect(@user.private_document_ids.length).to eq(0)
      # end

      it "remove one doc in list read" do
        @user.favour_document!(@doc)
        @user.read_document!(@doc)

        @doc.is_private = true
        @doc.private_for_id = @user.id
        @doc.save

        @user.reload
        expect(@user.favourite_document_ids.length).to eq(1)
        expect(@user.read_document_ids.length).to eq(1)
        expect(@user.private_document_ids.length).to eq(1)

        @user.remove_invalid_docs([@doc.id], [:read])
        @user.reload

        expect(@user.favourite_document_ids.length).to eq(1)
        expect(@user.read_document_ids.length).to eq(0)
        expect(@user.private_document_ids.length).to eq(1)
      end
    end
  end

  describe "check company paths" do
    context "ok" do
      before(:each) do
        create_default_data

        @all_paths = @company.all_paths_hash
      end

      it "when have valid path" do
        result = User.check_company_path_ids(@company, @all_paths.keys.first)

        expect(result[:valid]).to eq(true)

        result = User.check_company_path_ids(@company, @all_paths.keys.last)

        expect(result[:valid]).to eq(true)
      end
    end

    context "error case" do
      before(:each) do
        create_default_data

        @all_paths = @company.all_paths_hash
      end

      it "when have invalid node in path" do
        result = User.check_company_path_ids(@company, "#{@all_paths.keys.first}1")

        expect(result[:valid]).to eq(false)
        expect(result[:message].include?("Company area is invalid.")).to eq(true)
      end
    end
  end


  describe "read_document!:" do
    context "user read active document at the first time" do
      before(:each) do
        create_default_data({company_type: :standard})
      end

      it "user_document need to be updated updated_at, and this doc should be in sync" do
        u_comp = @user.user_company(@company)
        u_comp.company_path_ids = @doc.belongs_to_paths.first
        u_comp.save
        @user.reload
        @doc.reload

        #in test mode, it's not run the delayed job, so we will run it manually
        UserService.update_user_documents({user: @user, company: @company})

        old_updated_at = @user.company_documents(@company).where({document_id: @doc.id}).first.try(:updated_at)
        expect(old_updated_at).to_not eq(nil)

        sleep 2
        time = Time.now.utc.to_s
        sleep 2

        @user.read_document!(@doc)

        @user.reload
        @doc.reload

        new_docs = @user.new_docs(@company, {after_timestamp: time})

        expect(new_docs.count).to eq(1)
        expect(new_docs.first.id).to eq(@doc.id)

        new_updated_at = @user.company_documents(@company).where({document_id: @doc.id}).first.try(:updated_at)
        expect(old_updated_at).to_not eq(new_updated_at)
      end

    end
  end

  describe "document_is_inactive:" do
    context "when document is inactive" do
      before(:each) do
        create_default_data({company_type: :standard})
      end

      it "user_document need to be updated updated_at, and this doc should be in sync" do
        u_comp = assign_user_to_path(@user, @company, {company_path_ids: @doc.belongs_to_paths.first})
        @user.reload
        @doc.reload

        #in test mode, it's not run the delayed job, so we will run it manually
        UserService.update_user_documents({user: @user, company: @company})

        old_updated_at = @user.company_documents(@company).where({document_id: @doc.id}).first.try(:updated_at)
        expect(old_updated_at).to_not eq(nil)

        sleep 2
        time = Time.now.utc.to_s
        sleep 2

        @doc.expiry = Time.now.utc.advance(minutes: -1)
        @doc.save

        @user.reload
        @doc.reload
        UserService.update_user_documents({document: @doc, company: @company})

        new_docs = @user.new_docs(@company, {after_timestamp: time})

        expect(new_docs.count).to eq(1)
        expect(new_docs.first.id).to eq(@doc.id)

        new_updated_at = @user.company_documents(@company).where({document_id: @doc.id}).first.try(:updated_at)
        expect(old_updated_at).to_not eq(new_updated_at)
      end

    end
  end

  describe "reset_password:" do
    context "User request reset password" do
      before(:each) do
        create_default_data({company_type: :standard})
      end

      it "the new auto generated password should be valid" do
        u_comp = @user.user_company(@company)
        u_comp.company_path_ids = @doc.belongs_to_paths.first
        u_comp.save
        @user.reload

        (1..30).to_a.each do |i|
          new_password = @user.reset_password!
          @user.reload

          expect(@user.valid_password?(new_password)).to eq(true)
        end
      end

    end
  end
end