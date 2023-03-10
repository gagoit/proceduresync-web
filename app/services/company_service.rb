class CompanyService < BaseService
  extend ActionView::Helpers::TextHelper
  extend ActionView::Helpers::NumberHelper

  ##
  # + Invoices are generated on the first day of the month for the previous month. 
  #   The invoice is generated with Saasu (it is emailed), and the PDF will be stored on S3.
  # + Also a CSV of all the users will be generated and stored on S3.
  # + The amount of users are calculated by the amount of active users on the first day of the month when the invoice is generate.
  ##
  def self.monthly_payment
    calculate_for_time = Time.now.utc.advance(months: -1)
    Company.where(active: true, is_trial: false).all.each do |comp|
      monthly_payment_for_a_company(comp, calculate_for_time)
    end
  end

  ##
  # calculate & process payment for prev month for a company
  # - calculate_for_time: is the time in utc (month) that we are calculate & process payment for a company
  #   default is prev month
  ##
  def self.monthly_payment_for_a_company(comp, calculate_for_time = nil)
    calculate_for_time ||= Time.now.utc.advance(months: -1)
    month_str = calculate_for_time.strftime('%B_%Y')

    num_active_users = comp.users.active.count
    amount_users = num_active_users * comp.price_per_user

    puts "#{comp.id} : #{comp.name} : #{num_active_users} : #{amount_users} ----"

    file_users = active_users(comp)
    users_url = upload_file_to_s3(file_users, {path_on_s3: ["Active_Users", comp.id.to_s, month_str]})

    payment_result = stripe_charge(comp, num_active_users, users_url, month_str)

    SaasuService.create_invoice(comp, num_active_users, users_url, payment_result, calculate_for_time)
  end

  def self.active_users(comp, month_str = nil)
    month_str ||= Time.now.utc.advance(months: -1).strftime('%B_%Y')

    comp_all_paths_hash = comp.all_paths_hash

    users = comp.users.active.order_by([[:name, :asc]])

    file = CSV.generate({:write_headers => true}) do |csv|
      csv << ["Name", "Email", "Backup Email", "Belongs To", "Created At"] ## Header values of CSV

      users.each do |user|
        u_comp = user.user_company(comp, true)
        
        csv << [
          user.name,
          user.email,
          user.home_email,
          comp_all_paths_hash[u_comp["company_path_ids"]],
          BaseService.time_formated(comp, user.created_at)
        ]
      end
    end

    file_name = "Users_of_#{comp.name.gsub(' ', '_')}_in_#{month_str}.csv"
    folder = "tmp/#{month_str}"

    Dir::mkdir(folder) if Dir[folder].empty?

    f = File.open("#{folder}/#{file_name}", 'wb')
    f.write(file)
    f.flush
    f.close

    "#{folder}/#{file_name}"
  end

  def self.stripe_charge(comp, num_users = nil, users_url = "", month_str = nil)
    month_str ||= Time.now.utc.advance(months: -1).strftime('%B_%Y')

    num_users ||= comp.users.active.count
    amount = num_users * comp.price_per_user

    result = {charged: false}

    if !comp.stripe_customer_id.blank?
      begin
        @charge = Stripe::Charge.create(
          :customer    => comp.stripe_customer_id,
          :amount      => (amount.to_f * 100).to_i,
          :description => "Proceduresync Usage Fees #{month_str.gsub('_', ' ')} (#{pluralize(num_users, 'User')})",
          :currency    => "AUD"
        )

        result = {charged: true}
      rescue Exception => e
        BaseService.notify_or_ignore_error(e)
      end
    end

    unless result[:charged]
      Notification.when_credit_card_invalid(comp)
    end

    result
  end

  def self.invoices(current_user, company, options = {})
    invoices = company.invoices

    return_data = {
      "aaData" => [],
      "iTotalDisplayRecords" => 0,
      "iTotalRecords" => 0
    }

    invoices.each do |inv|
      price_per_user_text = number_to_currency(inv.price_per_user, {strip_insignificant_zeros: true})
      total_amount_text = number_to_currency(inv.total_amount, {strip_insignificant_zeros: true})

      inv_hash = {
        date: "#{Date::MONTHNAMES[inv.month]} #{inv.year}",
        total: inv.total_amount,
        total_text: "#{pluralize(inv.num_of_active_users, 'Users')} X #{price_per_user_text} per user. Total #{total_amount_text}",
        invoice_pdf: s3_signed_url(inv.invoice_pdf_url, {force_download: true, content_type: "application/pdf"}),
        users_csv: s3_signed_url(inv.active_users_url, {force_download: true, content_type: "application/csv"})
      }

      return_data["aaData"] << inv_hash

      return_data["iTotalDisplayRecords"] += 1
      return_data["iTotalRecords"] += 1
    end
    
    return_data
  end

  ##
  # Update document's areas, supervisor/approver areas, user's area when there is a new section is added to organisation
  # Example:
  # - If we add sub sections ???A??? to ???Rail > Rail Operations > Train Driver Mainline > Deepdale???. 
  #   We will update the documents' areas, supervisor/approver areas, user's area that content ???Rail > Rail Operations > Train Driver Mainline > Deepdale??? area
  #   to the newly created sections ???Rail > Rail Operations > Train Driver Mainline > Deepdale > A???
  # - Then if new sub sections B is added to ???Rail > Rail Operations > Train Driver Mainline > Deepdale???, we will do nothing
  ##
  def self.update_areas_when_create_new_sub_sections(company_id, node)
    return unless node && node.parent && (parent_path = node.parent.path)
    
    company = company_id.is_a?(Company) ? company_id : Company.find(company_id)

    company.user_companies.where(:company_path_ids => parent_path).each do |u_comp|
      u_comp.company_path_ids = node.path
      u_comp.save
    end

    company.documents.where(:belongs_to_paths.in => [parent_path]).each do |doc|
      doc.belongs_to_paths.delete(parent_path)
      doc.belongs_to_paths << node.path

      if doc.approved_paths.include?(parent_path)
        doc.approved_paths.delete(parent_path)
        doc.approved_paths << node.path
      end

      # Don't use Actice Record Save operation to Reduce update_user_documents query
      doc.correct_paths
      Document.where(:id => doc.id).update_all(belongs_to_paths: doc.belongs_to_paths, approved_paths: doc.approved_paths, 
            not_approved_paths: doc.not_approved_paths, not_accountable_for: doc.not_accountable_for)
      doc.create_logs({ user_id: node.updated_by_id, action: ActivityLog::ACTIONS[:updated_document], 
            attrs_changes: doc.changes })
    end

    company.user_companies.where(:approver_path_ids.in => [parent_path]).each do |u_comp|
      u_comp.approver_path_ids.delete(parent_path)
      u_comp.approver_path_ids << node.path
      u_comp.save(validate: false)
    end

    company.user_companies.where(:supervisor_path_ids.in => [parent_path]).each do |u_comp|
      u_comp.supervisor_path_ids.delete(parent_path)
      u_comp.supervisor_path_ids << node.path
      u_comp.save(validate: false)
    end

    #Check approver for Advanced or Hybird system when have new area
    if company.show_admin_attentions
      company.check_approver
    end
  end

  def self.validate_replicate_accountable_documents(company, params, updated_by_id: nil, just_validate: false)
    if params[:from_section] == params[:to_section]
      return {success: false, message: check_comp_path[:message], error_code: "error_company_paths"}
    end

    from_section_id = params[:from_section]
    to_section_id = params[:to_section]
    updated_by_id ||= User.admin.first.try(:id)

    check_comp_path = User.check_company_path_ids(company, from_section_id)
    unless check_comp_path[:valid]
      return {success: false, message: check_comp_path[:message], error_code: "error_company_paths"}
    end

    check_comp_path = User.check_company_path_ids(company, to_section_id)
    unless check_comp_path[:valid]
      return {success: false, message: check_comp_path[:message], error_code: "error_company_paths"}
    end

    unless just_validate
      self.delay(queue: "update_data").replicate_accountable_documents(company, params, updated_by_id: updated_by_id, need_validate: false)
    end

    {success: true, message: "Replicate Accountable Documents have been done successfully"}
  end

  # Have the facility for Super Admin to make one sections accountable documents the same as another.  
  # For instance, when we add a new section to the system we can make it???s accountable documents be the same as another current section 
  # so that we don???t have to go through and manually do it.  
  def self.replicate_accountable_documents(company, params, updated_by_id: nil, need_validate: true)
    if need_validate
      result = self.validate_replicate_accountable_documents(company, params, updated_by_id: updated_by_id, just_validate: true)
      return result unless result[:success]
    end

    from_section_id = params[:from_section]
    to_section_id = params[:to_section]
    updated_by_id ||= User.admin.first.try(:id)

    need_save = false
    use_active_record_save = false
    accountable_for_users_changed = false
    # => Find the way to reduce AR Save operation -> reduce update_user_documents job
      # We need to run update_user_documents job when approved_paths change
        # approved_paths change when:
          #1 - Doc need approval and Doc is approved for from_section_id
          #2 - Doc doesn't approval and Doc is belongs to from_section_id
        # *** ( but in this case: only the belongs_to_paths & approved_paths are changed so 
        #       we just add the users in from_section_id path to document's user_document relationship )

    user_ids_in_to_section = company.user_companies.where(:company_path_ids => to_section_id).pluck(:user_id)

    company.documents.where(:belongs_to_paths.in => [from_section_id, to_section_id]).each do |doc|
      need_save = false
      use_active_record_save = false
      accountable_for_users_changed = false

      if doc.belongs_to_paths.include?(from_section_id)
        unless doc.belongs_to_paths.include?(to_section_id)
          doc.belongs_to_paths << to_section_id
          need_save = true
        end

        if doc.approved_paths.include?(from_section_id) && !doc.approved_paths.include?(to_section_id)
          doc.approved_paths << to_section_id
          need_save = true
          accountable_for_users_changed = true
        end
      else
        doc.belongs_to_paths.delete(to_section_id)
        need_save = true
        use_active_record_save = true #1 & 2
      end

      next unless need_save

      if use_active_record_save
        doc.save(validate: false)

      else
        # Don't use Actice Record Save operation to Reduce update_user_documents query
        doc.correct_paths
        Document.where(:id => doc.id).update_all(belongs_to_paths: doc.belongs_to_paths, approved_paths: doc.approved_paths, 
              not_approved_paths: doc.not_approved_paths, not_accountable_for: doc.not_accountable_for)
        doc.create_logs({ user_id: updated_by_id, action: ActivityLog::ACTIONS[:updated_document], 
              attrs_changes: doc.changes })

        # Update UserDocument relationship for syncing
        next if user_ids_in_to_section.blank? || !accountable_for_users_changed || doc.is_private?

        DocumentService.delay(queue: "update_data").add_accountable_to_paths(company, doc, [to_section_id], {user_ids_in_paths: user_ids_in_to_section, new_paths: [to_section_id]})
      end
    end

    {success: true, message: "Replicate Accountable Documents have been done successfully"}
  end

end