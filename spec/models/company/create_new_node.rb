require 'spec_helper'

describe "Company: create new node" do

  ##
  #  Company has structures:
  #
  #   Division 1 > Depart 1 (doc)
  #   Division 1 > Depart 2
  #   Division 2 > Depart 3 (doc1)
  ##
  context "When parent node has no child before create" do
    before(:each) do
      create_default_data({company_type: :standard, create_doc: true})
    end

    it "=> docs that are in parent's node will be updated to new child node" do
      depart1 = @company.company_structures.where(name: "Depart 1").first
      
      group_node_1 = @company.company_structures.create({type: 'group', name: "Group 1", 
                      parent_id: depart1.id})

      CompanyService.update_areas_when_create_new_sub_sections(@company.id, group_node_1)

      @doc.reload

      expect(@doc.belongs_to_paths.include?(depart1.path)).to eq(false)      
      expect(@doc.belongs_to_paths.include?(group_node_1.path)).to eq(true)
    end
  end

  ##
  #  Company has structures:
  #
  #   Division 1 > Depart 1 (doc)
  #   Division 1 > Depart 2
  #   Division 2 > Depart 3 (doc1)
  ##
  context "When parent node has one child before create" do
    before(:each) do
      create_default_data({company_type: :standard, create_doc: true})
    end

    it "=> There is no change for docs that are in parent's node" do
      depart1 = @company.company_structures.where(name: "Depart 1").first
      
      puts "belongs_to_paths -0: #{@doc.belongs_to_paths.join(' || ')}"

      group_node_1 = @company.company_structures.create({type: 'group', name: "Group 1", 
                      parent_id: depart1.id})

      CompanyService.update_areas_when_create_new_sub_sections(@company.id, group_node_1)
      @doc.reload

      expect(@doc.belongs_to_paths.include?(depart1.path)).to eq(false)
      expect(@doc.belongs_to_paths.include?(group_node_1.path)).to eq(true)

      group_node_2 = @company.company_structures.create({type: 'group', name: "Group 2", 
                      parent_id: depart1.id})

      CompanyService.update_areas_when_create_new_sub_sections(@company.id, group_node_2)
      @doc.reload
      
      expect(@doc.belongs_to_paths.include?(group_node_2.path)).to eq(false)
    end
  end
end