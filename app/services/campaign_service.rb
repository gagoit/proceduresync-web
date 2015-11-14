class CampaignService < BaseService
  @@auth = {:api_key => CAMPAIGNS[:api_key]}

  def self.create_send
    @@create_send ||= CreateSend::CreateSend.new @@auth
  end

  def self.client
    @@client ||= CreateSend::Client.new( @@auth, CAMPAIGNS[:client_id])
  end

  def self.get_list(list_id)
    # Gets the details of this list.
    begin
      response = create_send.get "/lists/#{list_id}.json"

      Hashie::Mash.new(response).ListID
    rescue Exception => e
      nil
    end
  end

  # When company is created, we should create a list for this company in Campain monitor
  # create(auth, client_id, title, unsubscribe_page, confirmed_opt_in,
  #    confirmation_success_page, unsubscribe_setting="AllClientLists")
  def self.create_list(company)
    list = nil

    begin
      list = CreateSend::List.create(@@auth, CAMPAIGNS[:client_id], company.name, CAMPAIGNS[:unsubscribe_page], CAMPAIGNS[:confirmed_opt_in],
      CAMPAIGNS[:confirmation_success_page], CAMPAIGNS[:unsubscribe_setting])

      if list
        company.campaign_list_id = list
        company.save(validate: false)
      end

    rescue Exception => e
      #CreateSend::BadRequest: The CreateSend API responded with the following error - 250: List title must be unique within a client
      list = nil

      if e.message.include?("List title must be unique")
        list = get_list(company.campaign_list_id) if company.campaign_list_id

        if list.nil?
          all_lists = client.lists

          all_lists.each do |li|
            if li.Name == company.name
              list = li.ListID
              company.campaign_list_id = list
              company.save(validate: false)
              break
            end
          end
        end
      end
    end

    list
  end

  #https://github.com/campaignmonitor/createsend-ruby/blob/master/lib/createsend/list.rb#L169
  def self.update_list(company)
    if company.campaign_list_id.blank?
      create_list(company)
      company.reload
    end

    begin
      options = { 
        :body => {
          :Title => company.name,
          :UnsubscribeSetting => CAMPAIGNS[:unsubscribe_setting]
        }.to_json 
      }
      
      response = create_send.put "/lists/#{company.campaign_list_id}.json", options

    rescue Exception => e
      puts "error in CampaignService.update_list"
      puts e.message
    end
  end

  # When user is created/updated/changed company
  # => Each user will be added to all, their company & their position

  # https://www.campaignmonitor.com/api/subscribers/
  # POST https://api.createsend.com/api/v3.1/subscribers/{listid}.{xml|json}
  # date format:  yyyy/mm/dd
  def self.create_subscriber(user, company = nil)
    companies = company ? [company] : user.companies

    companies.each do |comp|
      if u_comp = user.user_company(comp)
        #update in user type list
        u_type = u_comp.user_type.to_sym rescue :standard_user
        change_subscriber_list(user, nil, CAMPAIGNS[:lists][u_type])

        #update in approver/supervisor list if user is approver/supervisor
        change_subscriber_list(user, nil, CAMPAIGNS[:lists][:approver_user]) if u_comp.is_approver && u_type != :approver_user
        change_subscriber_list(user, nil, CAMPAIGNS[:lists][:supervisor_user]) if u_comp.is_supervisor && u_type != :supervisor_user

        if comp.campaign_list_id.blank?
          create_list(comp)
          comp.reload
        end
        
        #update in company's list
        change_subscriber_list(user, nil, comp.campaign_list_id)
      end
    end
    
    change_subscriber_list(user, nil, CAMPAIGNS[:lists][:all])
  end

  ##
  # Update/Add user to Campaign monitor
  ##
  def self.update_subscriber(user)
    return if user.email.blank?
    
    create_subscriber(user)
  end

  ##
  # Unsubscribe user from old list
  # Add user to new list
  ##
  def self.change_subscriber_list(user, list_old, list_new)
    return if user.email.blank?
    puts "old: #{CAMPAIGNS[:lists].invert[list_old]}  --  new: #{CAMPAIGNS[:lists].invert[list_new]}"

    if list_old
      begin
        options = { :body => {
          :EmailAddress => user.email }.to_json }

        create_send.post "/subscribers/#{list_old}/unsubscribe.json", options
      rescue Exception => e
        puts "error in CampaignService.change_subscriber_list list_old"
        puts e.message
      end
    end

    if list_new
      begin
        custom_fields = []
        custom_fields << {"home_email" => user.home_email } if !user.home_email.blank?

        u_type_sub = CreateSend::Subscriber.add(@@auth, list_new, user.email, user.name, custom_fields, true, false)
      rescue Exception => e
        puts "error in CampaignService.change_subscriber_list list_new"
        puts e.message
      end
    end
  end

  ##
  # When use is inactive, remove user from Campaign monitor: 
  ##
  def self.remove_subscriber(user)
    return if user.email.blank?

    begin
      #remove in list all
      change_subscriber_list(user, CAMPAIGNS[:lists][:all], nil)

      #remove in user's type list and in company's list
      user.companies.each do |company|
        if u_comp = user.user_company(company)

          #remove in user's type list
          u_type = u_comp.user_type.to_sym rescue :standard_user
          change_subscriber_list(user, CAMPAIGNS[:lists][u_type], nil)
          
          #remove in company's list
          change_subscriber_list(user, company.campaign_list_id, nil)

          #remove in approver/supervisor list
          change_subscriber_list(user, CAMPAIGNS[:lists][:approver_user], nil) if u_comp.is_approver && u_type != :approver_user
          change_subscriber_list(user, CAMPAIGNS[:lists][:supervisor_user], nil) if u_comp.is_supervisor && u_type != :supervisor_user
        end
      end

    rescue Exception => e
      puts "error in CampaignService.remove_subscriber"
      puts e.message
    end
  end
end