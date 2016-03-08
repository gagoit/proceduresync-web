require 'spec_helper'

describe "Company: unread_percentage_of_section" do

  test_formula = lambda { |company, section, user_ids| 
    ## Calculate unread_docs_count,accountable_docs_count
    unread = 0
    total = 0
    user_ids.each do |id|
      u_c = company.user_companies.includes(:user).active.where(:user_id => id).first
      u_c.user.update_docs_count(company, u_c)

      u_c.reload

      unread += u_c.unread_docs_count
      total += u_c.accountable_docs_count
    end

    unread_percentage = section.unread_percentage

    return unread_percentage.to_s, ((unread/total.to_f)*100).round(2).to_s
  }

  get_user_ids_of_section = lambda { |company, section|
    ids = company.user_companies.active.where(:company_path_ids => section.path).pluck(:user_id)
    
    if section.child_ids.length == 0
      return ids
    else
      section.childs.each do |e|
        ids += get_user_ids_of_section.call(company, e)
      end

      return ids
    end
  }

  ##
  #  Company has structures:
  #
  #   Division 1 > Depart 1
  #   Division 1 > Depart 2
  #   Division 2 > Depart 3
  ##
  context "When section have no active users" do
    before(:each) do
      create_default_data({company_type: :standard})
    end

    it "OK" do
      u_comp = @user.user_company(@company)
      u_comp.company_path_ids = ""
      u_comp.save
      u_comp.reload

      user1 = create :user, token: "#{@user.token}11", company_ids: [@company.id], admin: false
      user1.reload
      @company.reload

      division1 = @company.company_structures.where(name: "Division 1").first
      user_ids = get_user_ids_of_section.call(@company, division1)

      unread_percentage, unread_percentage_r = test_formula.call(@company, division1, user_ids)
      expect(unread_percentage).to eq(unread_percentage_r)
    end
  end

  ##
  #  Company has structures:
  #
  #  Division 1 > Depart 1
  #  Division 1 > Depart 2
  #  Division 2 > Depart 3
  ##
  context "When section have active users" do
    before(:each) do
      create_default_data({company_type: :standard})
    end

    it "OK for parent node" do
      division1 = @company.company_structures.where(name: "Division 1").first

      u_comp = @user.user_company(@company)
      u_comp.company_path_ids = division1.childs.first.path
      u_comp.save
      u_comp.reload

      #user1 is not in @user's area
      user1 = create :user, token: "#{@user.token}11", company_ids: [@company.id], admin: false
      user1.reload
      @company.reload

      User.update_companies_of_user(user1, [], [@company.id])
      u1_comp = user1.user_company(@company)
      u1_comp.company_path_ids = division1.childs.last.path
      u1_comp.save

      #user2 is in @user's area
      user2 = create :user, token: "#{@user.token}111", company_ids: [@company.id], admin: false
      user2.reload
      @company.reload
      
      User.update_companies_of_user(user2, [], [@company.id])
      u2_comp = user2.user_company(@company)
      u2_comp.company_path_ids = u_comp.company_path_ids
      u2_comp.save

      @user.reload
      user1.reload
      user2.reload
      
      user_ids = get_user_ids_of_section.call(@company, division1)
      expect(user_ids.length).to eq(3)
      expect(user_ids.include?(@user.id)).to eq(true)
      expect(user_ids.include?(user1.id)).to eq(true)
      expect(user_ids.include?(user2.id)).to eq(true)

      unread_percentage, unread_percentage_r = test_formula.call(@company, division1, user_ids)
      expect(unread_percentage).to eq(unread_percentage_r)
    end

    ##
    #  Company has structures:
    #
    #  Division 1 > Depart 1
    #  Division 1 > Depart 2
    #  Division 2 > Depart 3
    ##
    it "OK for leaf node" do
      division1 = @company.company_structures.where(name: "Division 1").first
      depart1 = division1.childs.where(name: "Depart 1").first
      depart2 = division1.childs.where(name: "Depart 2").first

      u_comp = @user.user_company(@company)
      u_comp.company_path_ids = depart1.path
      u_comp.save
      u_comp.reload

      #user1 is not in @user's area
      user1 = create :user, token: "#{@user.token}11", company_ids: [@company.id], admin: false
      user1.reload
      @company.reload

      User.update_companies_of_user(user1, [], [@company.id])
      u1_comp = user1.user_company(@company)
      u1_comp.company_path_ids = depart2.path
      u1_comp.save

      #user2 is in @user's area
      user2 = create :user, token: "#{@user.token}111", company_ids: [@company.id], admin: false
      user2.reload
      @company.reload
      
      User.update_companies_of_user(user2, [], [@company.id])
      u2_comp = user2.user_company(@company)
      u2_comp.company_path_ids = depart2.path
      u2_comp.save

      @user.reload
      user1.reload
      user2.reload
      
      user_ids = get_user_ids_of_section.call(@company, depart1)
      expect(user_ids.length).to eq(1)
      expect(user_ids.include?(@user.id)).to eq(true)

      unread_percentage, unread_percentage_r = test_formula.call(@company, depart1, user_ids)
      expect(unread_percentage).to eq(unread_percentage_r)
    end
  end
end