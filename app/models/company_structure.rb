class CompanyStructure
  include Mongoid::Document
  include Mongoid::Timestamps

  field :type, type: String
  field :name, type: String
  field :path, type: String
  field :deleted, type: Boolean, default: false
  field :deleted_at, type: Time

  field :updated_by_id, type: String

  belongs_to :company

  has_many :childs, class_name: "CompanyStructure", order: [:name, :asc]
  belongs_to :parent, class_name: "CompanyStructure"

  validates_presence_of :name, :company_id, :type
  # validates_uniqueness_of :name, scope: :parent_id, :if => :is_not_company_node?

  validate :type, :inclusion => { :in => Company::STRUCTURES.keys.map { |e| e.to_s }}
  #['company', 'division', 'department', 'group', 'depot', 'panel']

  validate :parent_id, :presence => true, :if => :is_not_company_node?
  validates_uniqueness_of :type, scope: :company_id, :if => :is_company_node?

  index({type: 1, parent_id: 1, company_id: 1})
  index({parent_id: 1})
  index({company_id: 1})
  index({path: 1, company_id: 1})

  default_scope ->{where(:deleted.ne => true)}

  Company::STRUCTURES.keys.each do |e|
    scope e, -> {where(type: e.to_s)}
  end

  scope :by_company, ->(comp_id) {where(company_id: comp_id)}

  before_save do
    if is_company_node?
      self.parent_id = nil
    end
    self.path = calculate_path
    true
  end

  validate do
    if is_not_company_node? && parent
      parent_type = parent.type || ""
      child_type = Company::STRUCTURES[parent_type.to_sym][:child] rescue nil
      self.errors.add(:type, "is wrong")  unless (child_type && child_type == type)
    end

    if is_not_company_node? && deleted.blank? && name_changed?
      existed = company.company_structures.where(parent_id: parent_id, name: name).exists?
      self.errors.add(:name, "is existed") if existed
    end
  end

  after_save do
    if name_changed? || type_changed? || path_changed?
      Rails.cache.delete("/company/#{company.id}-#{company.path_updated_at}/company_paths")
      Rails.cache.delete("/company/#{company.id}-#{company.path_updated_at}/all_paths")
      Rails.cache.delete("/company/#{company.id}-#{company.path_updated_at}/all_paths_hash")
      Rails.cache.delete("/company/#{company.id}-#{company.path_updated_at}/all_paths_include_deleted")
      Rails.cache.delete("/company/#{company.id}-#{company.path_updated_at}/all_paths_hash_include_deleted")
      
      company.path_updated_at = self.updated_at

      if company.lowest_level != type
        all_types = Company::STRUCTURES.keys.map { |e| e.to_s }
        company.lowest_level = type if (all_types.index(company.lowest_level) < all_types.index(type) rescue true)
      end

      company.save(validate: false)
    end
  end

  after_create do
    #Update User's area if these areas are parent area of new organisation structure
    if parent && parent.path
      CompanyService.delay.update_areas_when_create_new_sub_sections(company_id, self)
    end
  end

  def is_not_company_node?
    type != 'company'
  end

  def is_company_node?
    type == 'company'
  end

  def name
    if is_company_node?
      self.company.name
    else
      super
    end
  end

  def calculate_path
    if is_company_node?
      id.to_s
    else
      [parent.path, id.to_s].join(Company::NODE_SEPARATOR)
    end
  end

  # Formula for each org section:  
  # (
  #   (Every "Active" user that belongs to that section's "Unread Document Total") 
  #   / 
  #   (Every "Active" user that belongs to that section's "Total Accountable") 
  #   ) x 100.   
  # This is colour coded. 0-5% Green, 6-10% Yellow, 11-15% Orange and >15% red.
  def unread_percentage
    users = company.user_companies.active.where(:company_path_ids => /^#{path}/i, :user_id.in => company.user_ids)

    unread_docs_count = users.sum(:unread_docs_count)
    accountable_docs_count = users.sum(:accountable_docs_count)

    ((unread_docs_count / accountable_docs_count.to_f) * 100).round(2) rescue 0
  end
end