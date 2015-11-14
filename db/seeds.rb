# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)
com = Company.find_or_create_by({name: "Appiphany"})

user = User.find_or_initialize_by({admin: true, name: "Admin", email: 'admin@appiphany.com.au', token: 'ADMINTOKEN', nickname: "Admin"})

if user.new_record?
  user.password = '123456789'
  user.password_confirmation = '123456789'
  user.company_ids = [com.id] if user.company_ids.blank?

  user.save

  puts user.valid?
end

# Document.all.each do |doc|
#   if version = doc.current_version
#     puts "#{doc.id} - #{doc.title} - #{version.version}"
#     begin
#       doc = BoxView::Models::Document.new(id: version.box_view_id)
#       doc.reload

#       attemps = 0
#       while (doc.status != "done" && doc.status != "error" )
#         attemps += 1

#         sleep 3
#         doc = doc.reload
#         puts "version: #{version.id} - attemps: #{attemps} - status: #{doc.status}"

#         break if attemps > 10
#       end

#       version.update_attributes({box_status: doc.status, attemps_num_download_converted_file: version.attemps_num_download_converted_file.to_i + 1})

#       if doc.status == "done"
#         DocumentService.download_zipfile_from_box(version, doc, 'pdf')
#       end
#     rescue Exception => e
#       puts "#{doc.id} -- #{e.message}"
#       version.update_attributes({box_status: "error"})
#     end
#   end
# end

# User.where(:phone => nil).update_all({phone: ""})

# Permission.all.each do |perm|
#   perm.save
# end

# #
# Company.all.each do |comp|

#   # Update lowest level for company
#   Company::STRUCTURES.keys.reverse.each do |level|
#     if comp.company_structures.where(type: level.to_s).first
#       comp.lowest_level = level.to_s
#       break
#     end
#   end

#   comp.private_folder_size = 100

#   comp.save(validate: false)

#   comp.create_default_data

#   comp.company_structures.each do |e|
#     e.save
#   end

#   #Update user companies
#   comp.users.each do |user|
#     u_comp = user.user_companies.find_or_initialize_by({:company_id => comp.id})

#     if u_comp_perm = u_comp.permission

#     elsif u_comp_perm = comp.permissions.where(:code => "standard_user").first
#       u_comp.permission_id = u_comp_perm.id
#     else
#       Permission.create_standard_permissions(comp)

#       u_comp_perm = comp.permissions.where(:code => "standard_user").first
#       u_comp.permission_id = u_comp_perm.id
#     end

#     # if user.company_path_ids.blank?
#     #   user.company_path_ids = comp.company_structures.where(:type => "company").first.path rescue ""
#     # end

#     u_comp.save
#   end
# end

# Permission.all.each do |perm|
#   perm.save
# end

# has_noti = (Notification.any_of({type: Notification::TYPES[:unread_document][:code]}, {type: Notification::TYPES[:unread_document][:code]}).count > 0)

# ## Update belongs_to_paths and some infos of documents
# Document.all.each do |doc|
#   doc.created_time = doc.created_at if doc.created_time.blank?
#   doc.category_name = doc.category.try(:name) || "Private"
#   doc.curr_version = (doc.current_version.version rescue '') if doc.curr_version.blank?
#   doc.curr_version_size = (doc.current_version.box_file_size rescue 0)
#   doc.effective_time = doc.created_time if doc.effective_time.blank?

#   doc.approved = (!doc.need_approval || !doc.approved_by_ids.blank?)

#   if doc.belongs_to_paths.blank?
#     doc.belongs_to_paths = [doc.company.company_structures.where(:type => "company").first.path] rescue []
  
#   elsif doc.current_version && !has_noti
#     Notification.when_doc_need_approve(doc) if doc.need_approval
#     Notification.when_doc_is_assign(doc)
#   end

#   doc.save(validate: false)
# end


# # Version.all.each do |version|
# #   next unless version.doc_file
# #   file_name = "tmp/#{version.document.id}-#{version.id}.pdf"
# #   file_name_encrypted = "tmp/#{version.document.id}-#{version.id}-encrypted.pdf"

# #   open(file_name, 'w', encoding: 'ASCII-8BIT') do |f|
# #     f << open(version.doc_file).read
# #   end

# #   #encrypt file
# #   XOREncrypt.encrypt_decrypt(file_name, version.document.company_id.to_s, file_name_encrypted)

# #   DocumentService.upload_file_to_s3(version, file_name_encrypted, "pdf")
# # end


# ## Update file_url for version

# Version.all.each do |version|
#   next if !version.file_url.blank? || version.file_file_name.blank?

#   Version.without_callback(:save, :after) do
#     version.file_name = version.file_file_name
#     version.file_url = version.file.url

#     version.save
#   end
# end

# #Change reports
# I18n.t("reports.form.doc_status.options").each do |key, value|
#   ReportSetting.where(:doc_status => value).update_all(doc_status: key.to_s)
# end

# I18n.t("report_setting.form.frequency.options").each do |key, value|
#   ReportSetting.where(:frequency => value).update_all(frequency: key.to_s)
# end

# [:frequency, :doc_status, :users, :categories].each do |key|
#   ReportSetting.where(key => "All").update_all(key => "all")
# end

# #Update User edit: Change "Admin User" to "Admin", "Supervisor User" to "Supervisor" ( 0.5hrs )
# Permission.where(name: "Admin User").update_all(name: Permission::STANDARD_PERMISSIONS[:admin_user][:name])
# Permission.where(name: "Supervisor User").update_all(name: Permission::STANDARD_PERMISSIONS[:supervisor_user][:name])
# Permission.where(name: "Standard User").update_all(name: Permission::STANDARD_PERMISSIONS[:standard_user][:name])

# #Jan 6, 2015: Update code in version for Document Settings
# Company.all.update_all({document_settings: []})
# Version.all.update_all(need_validate_required_fields: false)
# Document.all.update_all(need_validate_required_fields: false)
# User.all.each do |u|
#   u.read_document_ids += u.private_document_ids
#   u.read_document_ids.uniq!
#   u.save(validate: false)
# end

# #Add permission - "Can edit organisation structure". Only Company representative has this by default.
# #Allows access and editing to Organisation page.
# Permission.where(:code => "company_representative_user", can_edit_organisation_structure: nil).update_all(can_edit_organisation_structure: true)

# #Update user type + user_companies_info in user ( Jan 16, 2015 )
# #Add supervisor_path_ids in UserCompany (Jan 18, 2015)
# UserCompany.all.each do |e|
#   e.supervisor_path_ids = e.approver_path_ids if e.supervisor_path_ids.nil?
#   e.save
# end

# #Update automatic_email in report setting (default false)
# ReportSetting.where(:automatic_email => nil).update_all(automatic_email: false)

# Permission.where(:user_type => nil).each do |e|
#   e.save(validate: false)
# end

# #Update categories for each company:
# cate_hash = {} #company_id=> {comp: comp, category: category}
# Company.each do |comp|
#   categories = Category.where(:id.in => comp.documents.public_all.pluck(:category_id) )
#   categories.each do |category|
#     next if category.company
    
#     cate_hash[comp.id] = {
#       comp: comp,
#       category: category
#     }
#   end
# end

# cate_hash.each do |key, value|
#   comp = value[:comp]
#   cate = value[:category]

#   new_cate = comp.categories.create({name: cate.name})

#   comp.documents.where(:category_id => cate.id).update_all(:category_id => new_cate.id)
#   Category.where(:id => new_cate.id).update_all(:document_ids => comp.documents.where(:category_id => cate.id).pluck(:id))

#   cate.destroy
# end

# #Jan 29, 2015: Update curr_version in document when document have no current_version
# Document.all.each do |doc|
#   next if doc.curr_version || (c_v = doc.current_version).nil?

#   Document.where(id: doc.id).update_all({:curr_version => c_v.version})
# end

# Permission.where(:user_type => nil).each do |e|
#   e.save(validate: false)
# end

#Jan 31, 2015: Add approved_paths in document
# Document.all.each do |doc|
#   if doc.approved_paths.blank? && doc.approved
#     Document.where(id: doc.id).update_all(approved_paths: doc.belongs_to_paths, not_approved_paths: [])
#   end

#   doc.reload
#   if doc.need_approval && doc.not_approved_paths.blank?
#     if doc.approved
#       Document.where(id: doc.id).update_all(not_approved_paths: (doc.belongs_to_paths - doc.approved_paths))
#     else
#       Document.where(id: doc.id).update_all(not_approved_paths: doc.belongs_to_paths)
#     end
#   end
# end

#Feb 03, 2015

# User.all.each do |user|
#   user.companies.each do |company|
#     begin
#       UserService.update_user_documents({user: user, company: company})
#     rescue Exception => e
#       u_comp = user.user_company(company)

#       u_comp.save

#       begin
#         UserService.update_user_documents({user: user, company: company})
#       rescue Exception => e
#         puts "-------error: #{e}"
#         puts u_comp.reload.inspect
#       end
#     end
#   end
# end

#Update path of areas in Company
# Company.all.each do |company|
#   all_paths_hash = company.all_paths_hash
#   path_ids = all_paths_hash.keys

#   company.documents.each do |doc|
#     doc.belongs_to_paths = doc.belongs_to_paths & path_ids
#     doc.approved_paths = doc.approved_paths & path_ids
    
#     doc.save
#   end

#   company.user_companies.each do |u_comp|
#     u_comp.approver_path_ids = u_comp.approver_path_ids & path_ids
#     u_comp.supervisor_path_ids = u_comp.supervisor_path_ids & path_ids
    
#     u_comp.save
#   end
# end

# if ApproverDocument.count == 0
#   Document.where(:need_approval => true, :approved_paths.ne => []).each do |doc|
#     puts "----------#{doc.title} --- #{doc.id} -- "

#     approver_id = doc["approved_by_id"]
#     comp = doc.company
#     approved_paths = []
#     approved_by_ids = []

#     doc.logs.where(:action => "approved_document").order([:action_time, :asc]).pluck(:user_id, :action_time, :id).each do |log|
#       if approver = comp.users.where(id: log[0]).first
#         u_comp = approver.user_company(comp, true)

#         approved_paths_e = (doc.approved_paths & u_comp["approver_path_ids"])

#         if approved_paths_e.blank?
#           doc.logs.where(:action => "approved_document", :id => log[2]).destroy_all
#         else
#           approver_doc = doc.approver_documents.find_or_initialize_by({user_id: approver_id})
#           approver_doc.approve_document_to = "approve_selected_areas"
#           approver_doc.approved_paths = approved_paths_e
#           approver_doc.params = {:approve_document_to => "approve_selected_areas", belongs_to_paths: approved_paths_e}

#           approver_doc.save

#           approved_paths.concat(approved_paths_e)

#           approver_doc.update_attributes({created_at: log[1]}) if log[1] #approved time

#           approved_by_ids << approver.id
#         end
#       else
#         doc.logs.where(:action => "approved_document", :id => log[2]).destroy_all
#       end
#     end

#     if approved_paths.blank?
#       doc.approved = false
#       doc.approved_paths = []
#       doc.approved_by_ids = []
#     else
#       doc.approved = true
#       doc.approved_paths = approved_paths
#       doc.approved_by_ids = approved_by_ids
#     end

#     puts doc.save
#   end
# end

# Version.where(file_size: nil).update_all(file_size: 0.0)

# Document.where(:effective_time.lte => Time.now.utc).update_all(effective: true)
# Document.any_of({:effective_time.gt => Time.now.utc}, {effective_time: nil}).update_all(effective: false)

#Mar 7, 2015: Update user - favourite documents to UserDocument collection
# User.all.each do |user|
#   user.favourite_documents.includes(:company).each do |doc|
#     UserService.update_user_documents_when_status_change({user: user, document: doc, company: doc.company})
#   end
# end


#Mar 19, 2015:
#Default Permissions: Lets allow approvers to have "View User Read Receipt Reports under Assignment" checked
# Permission.standard.where(code: STANDARD_PERMISSIONS[:approver_user][:code]).each do |e|
#   e.update_attributes(view_all_user_read_receipt_reports_under_assignment: true)
# end

#Mar 22, 2015: Reupload document to set non_svg = true
# per_page = 50
# total = Version.count
# num_page = total/per_page + 1

# (1..num_page).to_a.each do |page|
#   Version.all.order([:created_at, :asc]).page(page).per(per_page).each do |version|
#     begin
#       next if version.file_url.blank?

#       doc = BoxView::Api::Document.new.upload(version.file_url, "#{version.file_name}-#{version.code}")

#       attemps = 0
#       while (doc.status != "done" && doc.status != "error" )
#         attemps += 1

#         sleep 3
#         doc = doc.reload
#         puts "version: #{version.id} - attemps: #{attemps} - status: #{doc.status}"

#         break if attemps > 10
#       end

#       version.update_attributes({box_status: doc.status, box_view_id: doc.id})

#       if doc.status == "done"
#       elsif doc.status == "error"
#         puts "Document is falied when uploaded: #{version.document.try(:title)} with version #{version.id}"
#       end
#     rescue Exception => e
#       puts "upload-doc-to-box failed: #{e.message}"
#     end
#   end
# end

#Mar 23, 2015:
#Update term and service
# url = "https://proceduresync-prod.s3.amazonaws.com/uploads%2F1423032287687-aw0dwnxnsppvte29-fb8743dd654d544db460a229211adb9f%2FProceduresync_Terms_and_Conditions.pdf"
# doc = BoxView::Api::Document.new.upload(url, "Proceduresync_Terms_and_Conditions")

# attemps = 0
# while (doc.status != "done" && doc.status != "error" )
#   attemps += 1
#   sleep 3
#   doc = doc.reload
#   break if attemps > 100
# end

# puts doc.id

# #Accountable report permission
# comp_reps_code = Permission::STANDARD_PERMISSIONS[:company_representative_user][:code]
# Permission.where(user_type: comp_reps_code).update_all(view_all_accountability_reports: true, view_accountability_reports_under_assignment: true)

# #Mar 30, 2015:
# #Add "Is Supervisor User" permission
# # => Add is_supervisor_user to company_representative_user and supervisor_user
# comp_reps_code = Permission::STANDARD_PERMISSIONS[:company_representative_user][:code]
# supervisor_user_code = Permission::STANDARD_PERMISSIONS[:supervisor_user][:code]
# Permission.where(:user_type.in => [comp_reps_code, supervisor_user_code], :is_supervisor_user.ne => true).each do |perm|
#   perm.is_supervisor_user = true
#   perm.save
# end

# #Add permission "Bulk assign documents" - this is for the purpose of approvers/supervisors 
# #can assign other non-restricted documents to the areas that they supervise
# Permission.where(bulk_assign_documents: nil).update_all(bulk_assign_documents: false)

# need_update_perms = [:company_representative_user, :approver_user].map { |e|  
#   Permission::STANDARD_PERMISSIONS[e][:code]
# }

# Permission.where(:user_type.in => need_update_perms).each do |perm|
#   perm.bulk_assign_documents = true
#   perm.save
# end

# #Approval Email Settings:
# UserCompany.each do |u_comp|
#   u_comp.approval_email_settings = UserCompany::APPROVAL_EMAIL_SETTINGS[:email_instantly]
#   u_comp.save
# end

# #Add restricted areas
# Document.update_all(:restricted_paths => [])

# #Add areas to report page for Add/Edit Permission
# ReportSetting.update_all(areas: ReportSetting::SELECT_USERS_TEXT)

# #Allow users, and categories is multiple select in Report
# ReportSetting.each do |e|
#   e.users = [e.users]
#   e.categories = [e.categories]
#   e.save
# end

# #Reset admin_attention
# Company.check_approver

# #Create indexes for dynamic collections
# Company.all.each do |comp|
#   comp.create_indexes_for_dynamic_collections
# end

# ## Update log
# Company.all.each do |comp|
#   acts = comp.logs

#   acts.each do |act|
#     #view_company_log
#     i_hash, add_text = LogService.get_more_log_info(act, nil, comp, "company")

#     comp_act_text = I18n.t("logs.company.#{act.action}", i_hash)
#     comp_act_text = "#{comp_act_text} #{add_text.join(', ')}" if add_text.length > 0

#     #view_document_log
#     i_hash, add_text = LogService.get_more_log_info(act, nil, comp, "document")

#     doc_act_text = I18n.t("logs.document.#{act.action}", i_hash)
#     doc_act_text = "#{doc_act_text} #{add_text.join(', ')}" if add_text.length > 0

#     #view_user_log
#     i_hash, add_text = LogService.get_more_log_info(act, nil, comp, "user")

#     user_act_text = I18n.t("logs.user.#{act.action}", i_hash)
#     user_act_text = "#{user_act_text} #{add_text.join(', ')}" if add_text.length > 0

#     comp.logs.where(id: act.id).update_all({
#       view_company_log: comp_act_text, view_document_log: doc_act_text, view_user_log: user_act_text
#     })
#   end
# end


# ##
# # August 4, 2015: create text index for current version of document
# ##
# per_page = 200
# versions = Version.where(box_status: "done").order([:created_at, :asc])
# num_page = versions.count/per_page + 1

# def update_text_content(version)
#   begin
#     puts "--- #{version.id}"
#     return if version.box_status != "done" || (document = version.document).blank?

#     puts "--- load box doc"
#     box_doc = BoxView::Models::Document.new(id: version.box_view_id)
#     box_doc.reload

#     puts "--- save pdf file"
#     file_name = "tmp/#{version.document_id}-#{version.id}.pdf"

#     f = File.open(file_name, 'w', encoding: 'ASCII-8BIT')
#     f.write(box_doc.content("pdf"))
#     f.flush
#     f.close

#     puts "--- get text content"
#     ## Get content of file
#     is_current_version = (document.current_version.try(:id) == version.id) 
    
#     pdf = Grim.reap(file_name)         # returns Grim::Pdf instance for pdf
#     pages = pdf.map { |e| e.text }

#     if is_current_version
#       d_content = DocumentContent.find_or_initialize_by({document_id: version.document_id, company_id: document.company_id})
#       d_content.title = document.title
#       d_content.doc_id = document.doc_id
#       d_content.company = document.company_id
#       d_content._keywords = document._keywords
#       d_content.pages = pages
#       d_content.save
#     end

#     file_txt_name = "tmp/#{version.document_id}-#{version.id}.txt"
#     file_txt_name_encrypted = "tmp/#{version.document_id}-#{version.id}-encrypted.txt"

#     puts "--- save text content"
#     f_t = File.open(file_txt_name, 'w', encoding: 'ASCII-8BIT')
#     f_t.write(pages.join(" "))
#     f_t.flush
#     f_t.close

#     puts "--- encrypt and upload text file to S3"
#     #encrypt txt file
#     #XOREncrypt.encrypt_decrypt(file_txt_name, document.id.to_s, file_txt_name_encrypted, 4)
#     #DocumentService.upload_file_to_s3(version, file_txt_name_encrypted, "txt")

#     version.reload
#     version.text_file_size = File.size(file_txt_name)
#     version.save(validate: false)

#     Document.where(:id => document.id).update_all(curr_version_text_size: (version.text_file_size || 0))

#     File.delete(file_name)
#     File.delete(file_txt_name)
#   rescue Exception => e
#     puts "upload-doc-to-box failed: #{document.id} -- #{e.message}"
#   end
# end

# per_page = 200
# documents = Document.all.order([:created_at, :asc])
# num_page = documents.count/per_page + 1

# (1..num_page).to_a.each do |page|
#   documents.page(page).per(per_page).each do |document|
#     next unless (version = document.current_version)

#     update_text_content(version)
#   end
# end


# Document.all.each do |doc|
#   d_content = DocumentContent.find_or_initialize_by(document_id: doc.id)
#   d_content.title = doc.title
#   d_content.doc_id = doc.doc_id
#   d_content._keywords = doc._keywords
#   d_content.company_id = doc.company_id
#   d_content.save(validate: false)
# end

# DocumentContent.create_text_indexes


## Oct 8, 2015:
## Update active in user_company
active_user_ids = User.active.pluck(:id)

UserCompany.where(:user_id.in => active_user_ids).update_all(active: true)

UserCompany.where(:user_id.nin => active_user_ids).update_all(active: false)