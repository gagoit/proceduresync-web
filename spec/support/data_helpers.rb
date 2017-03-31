def clean_data
  CompanyStructure.destroy_all
  ActivityLog.destroy_all
  AdminAttention.destroy_all
  Notification.destroy_all
  Permission.destroy_all
  UserCompany.destroy_all
  
  Version.destroy_all
  Document.destroy_all
  Category.destroy_all
  Delayed::Job.destroy_all
  
  Company.all.each do |company|
    UserDocument.with(collection: "#{company.id}_user_documents").destroy_all
  end

  User.destroy_all

  Company.destroy_all

  Rails.cache.clear rescue nil
end

def create_default_data(options = {company_type: :standard})
  clean_data

  options = {
    company_type: :standard
  }.merge(options)

  options[:create_doc] = true unless options.has_key?(:create_doc)

  @company = create :company, type: Company::TYPES[options[:company_type]]

  comp_node = @company.company_structures.where(type: "company", name: @company.name).first

  division_node_1 = @company.company_structures.create({type: 'division', name: "Division 1", 
                      parent_id: comp_node.id})
  division_node_2 = @company.company_structures.create({type: 'division', name: "Division 2", 
                      parent_id: comp_node.id})

  depart_node_1 = @company.company_structures.create({type: 'department', name: "Depart 1", 
                      parent_id: division_node_1.id})
  depart_node_2 = @company.company_structures.create({type: 'department', name: "Depart 2", 
                      parent_id: division_node_1.id})
  depart_node_3 = @company.company_structures.create({type: 'department', name: "Depart 3", 
                      parent_id: division_node_2.id})

  @category = create :category, company_id: @company.id

  @admin = create :user, admin: true
  @user = create :user, token: "#{@admin.token}1", company_ids: [@company.id], admin: false

  @user.reload
  @company.reload

  User.update_companies_of_user(@user, [], [@company.id])

  if options[:create_doc]
    @doc = create :document, category_id: @category.id, company_id: @company.id, belongs_to_paths: [depart_node_1.path]
    @version = create :version, document_id: @doc.id, box_status: "done", box_file_size: 100
    
    @doc.curr_version = @version.version
    @doc.save

    @doc1 = create :document, category_id: @category.id, company_id: @company.id, belongs_to_paths: [depart_node_3.path]
    @version1 = create :version, document_id: @doc1.id, box_status: "done", box_file_size: 100

    @doc1.curr_version = @version1.version
    @doc1.save

    @doc.reload
    @version.reload
    @doc1.reload
    @version1.reload

    DocumentContent.create_text_indexes
  end

  @user.reload
  @company.reload
  Rails.cache.clear
  
  @all_paths = @company.all_paths_hash
end

def create_doc(company, options = {document: {}, version: {}})
  options[:document] ||= {}
  options[:version] ||= {}

  doc_hash = {

    }.merge(options[:document])
  doc_hash[:company_id] = @company.id

  version_hash = {
    box_status: "done",
    box_file_size: 100
  }.merge(options[:version])

  doc = create :document, doc_hash

  version_hash[:document_id] = doc.id
  version = create :version, version_hash
  
  doc.curr_version = version.version
  doc.save

  doc.reload
  version.reload

  DocumentContent.create_text_indexes

  return doc, version
end

def create_private_doc(user, company)
  doc = create :document, company_id: company.id, is_private: true, private_for_id: user.id
  version = create :version, document_id: doc.id, box_status: "done", box_file_size: 100

  doc.curr_version = "1.0"
  doc.save

  doc.reload
  version.reload

  DocumentContent.create_text_indexes

  return doc, version
end

def assign_permission(user, company, perm_type)
  u_comp = user.user_company(company)

  company.reload

  perm = company.permissions.where(code: perm_type.to_s).first
  u_comp.permission_id = perm.id
  u_comp.save
end

def create_user(company, options = {info: {}, paths: {}})
  u_hash = {
    token: User.access_token,
    admin: false
  }.merge(options[:info] || {})

  u_hash[:company_ids] = [company.id]

  user = create :user, u_hash
  user.reload
  company.reload
  
  User.update_companies_of_user(user, [], [company.id])
  u_comp = user.user_company(company)

  if options[:paths]
    u_comp = assign_user_to_path(user, company, options[:paths])
  end

  return user.reload, u_comp.reload
end

def assign_user_to_path(user, company, options = {})
  u_comp = user.user_company(company)

  u_comp.company_path_ids = options[:company_path_ids] if options.has_key?(:company_path_ids)
  u_comp.supervisor_path_ids = options[:supervisor_path_ids] if options.has_key?(:supervisor_path_ids)
  u_comp.approver_path_ids = options[:approver_path_ids] if options.has_key?(:approver_path_ids)
  u_comp.permission_id = options[:permission_id] if options.has_key?(:permission_id)
  
  u_comp.save

  u_comp.reload
end