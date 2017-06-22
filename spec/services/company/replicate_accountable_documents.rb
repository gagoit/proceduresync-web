require 'spec_helper'

describe "CompanyService:" do
  describe "replicate_accountable_documents" do

    context "When user submit valid sections" do
      before(:each) do
        
      end

      it "do replicate_accountable_documents from from_section to to_section for only accountable documents" do
        create_default_data({company_type: :standard})

        from_section = @doc.belongs_to_paths[0]
        to_section = @doc1.belongs_to_paths[0]

        result = CompanyService.replicate_accountable_documents(@company, {from_section: from_section, to_section: to_section})
        
        expect(result[:success]).to eq(true)

        @doc.reload
        @doc1.reload

        expect(@doc.belongs_to_paths.include?(to_section)).to eq(true)
        expect(@doc1.belongs_to_paths.include?(to_section)).to eq(false)
      end

      it "do replicate_accountable_documents from from_section to to_section for need approval documents" do
        create_default_data({company_type: :advanced})

        from_section = @doc.belongs_to_paths[0]
        to_section = @doc1.belongs_to_paths[0]

        result = CompanyService.replicate_accountable_documents(@company, {from_section: from_section, to_section: to_section})
        
        expect(result[:success]).to eq(true)

        @doc.reload
        @doc1.reload

        expect(@doc.belongs_to_paths.include?(to_section)).to eq(true)
        expect(@doc1.belongs_to_paths.include?(to_section)).to eq(false)
      end

      it "do replicate_accountable_documents from from_section to to_section for need approval documents, also for approved_paths" do
        create_default_data({company_type: :advanced})

        from_section = @doc.belongs_to_paths[0]
        @doc.approved_paths << from_section
        @doc.save

        to_section = @doc1.belongs_to_paths[0]

        result = CompanyService.replicate_accountable_documents(@company, {from_section: from_section, to_section: to_section})
        
        expect(result[:success]).to eq(true)

        @doc.reload
        @doc1.reload

        expect(@doc.belongs_to_paths.include?(to_section)).to eq(true)
        expect(@doc.approved_paths.include?(to_section)).to eq(true)
        expect(@doc1.belongs_to_paths.include?(to_section)).to eq(false)
      end

      context "Update UserDocument relationship for User's in to_section (new)" do
        before(:each) do
          create_default_data({company_type: :standard})

          @from_section = @doc.belongs_to_paths.first
          @u_comp = assign_user_to_path(@user, @company, {company_path_ids: @from_section})
        end

        it "when has accountable docs in from_section that aren't in to_section" do
          to_section = (@all_paths.keys - @doc.belongs_to_paths).first
          user1, u1_comp = create_user(@company, {paths: {company_path_ids: to_section}})

          # expect(@doc.company_users(@company).accountable.pluck(:user_id).include?(user1.id)).to eq(false)
          expect(@doc.company_users(@company).pluck(:user_id).include?(user1.id)).to eq(false)

          result = CompanyService.replicate_accountable_documents(@company, {from_section: @from_section, to_section: to_section})
          
          expect(result[:success]).to eq(true)

          @doc.reload
          @doc1.reload

          expect(@doc.belongs_to_paths.include?(to_section)).to eq(true)
          expect(@doc.approved_paths.include?(to_section)).to eq(true)

          DocumentService.add_accountable_to_paths(@company, @doc, [to_section])

          # expect(@doc.company_users(@company).accountable.pluck(:user_id).include?(user1.id)).to eq(true)
          expect(@doc.company_users(@company).pluck(:user_id).include?(user1.id)).to eq(true)

          WebNotification.create_from_document(
            @doc, 
            { new_version: false, new_avai_user_ids: [user1.id] }
          )

          noti = Notification.where({user_id: user1.id, company_id: @company.id, 
            type: Notification::TYPES[:unread_document][:code], document_id: @doc.id}).first

          expect(noti.present?).to eq(true)
          expect(noti.status).to eq(Notification::UNREAD_STATUS)

          expect(@doc1.belongs_to_paths.include?(to_section)).to eq(false)
        end
      end
    end

    context "When user submit in-valid sections" do
      before(:each) do
        create_default_data({company_type: :standard})
      end

      it "return error" do
        from_section = @doc.belongs_to_paths[0]
        to_section = ""

        result = CompanyService.replicate_accountable_documents(@company, {from_section: from_section, to_section: to_section})
        
        expect(result[:success]).to eq(false)
        expect(result[:error_code]).to eq("error_company_paths")

        @doc.reload
        @doc1.reload

        expect(@doc.belongs_to_paths.include?(to_section)).to eq(false)
      end
    end
  end

end