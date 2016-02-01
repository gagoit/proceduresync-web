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