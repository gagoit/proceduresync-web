require 'open-uri'

class Company
  include Mongoid::Document
  include Mongoid::Paperclip
  include Mongoid::Timestamps

  STRUCTURES = {
    company: {
      parent: nil,
      child: "division"
    },
    division: {
      parent: "company",
      child: "department"
    },
    department: {
      parent: "division",
      child: "group"
    },
    group: {
      parent: "department",
      child: "depot"
    },
    depot: {
      parent: "group",
      child: "panel"
    },
    panel: {
      parent: "depot",
      child: nil
    }
  }

  NODE_SEPARATOR = " > "

  TYPES = {
    standard: "Standard",
    advanced: "Advanced",
    hybrid: "Hybrid"
  }

  DOCUMENT_SETTINGS_LIST = ["doc_id", "version", "expiry"]

  field :name, type: String

  field :address, type: String
  field :suburb_city, type: String
  field :state_district, type: String
  field :country, type: String
  field :phone, type: String
  field :fax, type: String
  field :abn_acn, type: String #Only show ABN/ACN if Australia is selected as a company
  field :invoice_email, type: String

  #Credit card
  field :credit_card_number, type: String
  field :name_on_card, type: String
  field :card_expiry, type: String
  field :card_ccv, type: String

  field :stripe_token, type: String
  field :stripe_customer_id, type: String

  #BillingContactId in Saasu
  field :saasu_contact_id, type: Integer

  has_mongoid_attached_file :logo, styles: { thumb: ["144x90", :jpg],
                                                iphone4: ["464x464", :jpg],
                                                original: ["", :jpg] },
                                    convert_options: {all: ["-unsharp 0.3x0.3+5+0", "-quality 90%", "-auto-orient"]},
                                    processors: [:thumbnail] ,
                                    storage: Rails.env.production? ? :s3 : :filesystem,
                                    s3_permissions: :public_read,
                                    s3_credentials: {access_key_id: CONFIG['amazon_access_key'],
                                                     secret_access_key: CONFIG['amazon_secret'],
                                                     bucket: CONFIG[:bucket]},
                                    default_url: "https://s3.amazonaws.com/proceduresync-prod/missing-:style.png"

  validates_attachment_content_type :logo, :content_type => /\Aimage/ #:content_type => %w(image/png image/jpg image/jpeg image/gif)

  field :company_label, type: String, default: "Company"
  field :division_label, type: String, default: "Division"
  field :department_label, type: String, default: "Department"
  field :group_label, type: String, default: "Group"
  field :depot_label, type: String, default: "Depot"
  field :panel_label, type: String, default: "Panel"

  field :type, type: String, default: TYPES[:standard]
  field :is_trial, type: Boolean, default: false
  field :trial_expiry, type: Time
  field :active, type: Boolean, default: true

  field :private_folder_size, type: Integer, default: 100

  field :lowest_level, type: String, default: "company"

  field :path_updated_at, type: Time

  field :timezone, type: String, default: 'Melbourne'
  field :price_per_user, type: Float, default: 1.0

  field :campaign_list_id, type: String

  field :document_settings, type: Array, default: [] #list of required field for document

  has_and_belongs_to_many :users, class_name: "User", inverse_of: :companies, order: [:name, :asc]

  field :updated_by_id, type: String

  has_many :documents

  has_many :permissions, order: [:created_at, :asc]

  has_many :user_companies

  has_many :company_structures

  has_many :admin_attentions

  has_many :activity_logs

  has_many :import_users

  has_many :invoices, order: [:created_at, :desc]

  has_many :categories, order: [:name, :asc]

  scope :active, -> {where(active: true)}

  validates_presence_of :name
  validates_uniqueness_of :name

  after_create do
    if self.valid?
      create_default_data 
      create_indexes_for_dynamic_collections
    end
  end

  validate do
    if card_expiry.blank? || card_ccv.blank? || credit_card_number.blank? || name_on_card.blank?
      self.stripe_token = nil
      self.stripe_customer_id = nil
    else
      if card_expiry_changed? && card_expiry
        exp_month = card_expiry.split("/")[0].to_i rescue 0
        exp_year = card_expiry.split("/")[1].to_i rescue 0

        if exp_month <= 0 || exp_month > 12 || exp_year <= 0 || exp_year > 9999
          self.errors.add(:card_expiry, "is invalid format")
        end
      end

      if card_ccv_changed? && card_ccv.length != 3 && card_ccv.length != 4
        self.errors.add(:card_ccv, "must be in 3- or 4-digit")
      end

      if credit_card_number_changed? && credit_card_number
        begin
          stripe_card = Stripe::Token.create(
            :card => {
              :number => credit_card_number,
              :exp_month => card_expiry.split("/")[0].to_i,
              :exp_year => card_expiry.split("/")[1].to_i,
              :cvc => card_ccv
            },
          )

          stripe_customer = Stripe::Customer.create(
            :description => "Customer for Proceduresync",
            :card  => stripe_card.id
          )

          self.stripe_token = stripe_card.id
          self.stripe_customer_id = stripe_customer.id
          last_digts = self.credit_card_number[(self.credit_card_number.length-4)..(self.credit_card_number.length - 1)]
          self.credit_card_number = "#{'#' * (self.credit_card_number.length - 4)}#{last_digts}"
        rescue Exception => e
          puts e.message
          self.errors.add(:base, e.message)
        end
      end
    end
  end

  after_save do
    if name_changed? || logo_file_name_changed? || active_changed?
      NotificationService.delay.company_has_been_changed(self)
    end

    if name_changed?
      CampaignService.delay.update_list(self)
    end

    if user_ids_changed?
      old_user_ids = self.user_ids_was || []
      new_user_ids = self.user_ids || []
      removed_user_ids = (old_user_ids-new_user_ids)
      added_user_ids = (new_user_ids-old_user_ids)

      NotificationService.delay.users_companies_have_been_changed([self.id], removed_user_ids, :removed)
      NotificationService.delay.users_companies_have_been_changed([self.id], added_user_ids, :added)

      User.delay.remove_invalid_docs((old_user_ids-new_user_ids), self.document_ids)

      if removed_user_ids.length > 0
        User.where(:id.in => removed_user_ids).each do |u|
          u.remove_company(self)
        end
      end

      if added_user_ids.length > 0
        User.where(:id.in => added_user_ids).each do |u|
          u.add_company(self)
        end
      end
    end

    #Create approver permission for Advanced and Hybrid system
    if type_changed? && !is_standard?
      approver_perm = Permission::STANDARD_PERMISSIONS[:approver_user]

      perm_hash = { name: approver_perm[:name], code: approver_perm[:code] }

      approver_perm[:permissions].each do |perm|
        perm_hash[perm] = true
      end

      self.permissions.create(perm_hash)
    end

    [:name, :address, :suburb_city, :state_district, :country, :phone, :fax, :abn_acn, 
      :invoice_email, :credit_card_number, :name_on_card, :card_expiry, :card_ccv].each do |field|

      if self.send(:"#{field}_changed?")
        self.create_logs({user_id: updated_by_id, action: ActivityLog::ACTIONS[:updated_company], attrs_changes: self.changes})
        break
      end
    end
  end

  ##
  # Create indexes for some dynamic collections
  ##
  def create_indexes_for_dynamic_collections
    session = Mongoid::Sessions.default

    #ActivityLog
    comp_activity_logs = session["#{self.id}_activity_logs"]

    ActivityLog::INDEXES.each do |ind|
      comp_activity_logs.indexes.create(ind)
    end

    #UserDocument
    comp_user_documents = session["#{self.id}_user_documents"]

    UserDocument::INDEXES.each do |ind|
      comp_user_documents.indexes.create(ind)
    end

  end

  def is_standard?
    type == TYPES[:standard]
  end

  def is_advanced?
    type == TYPES[:advanced]
  end

  def is_hybrid?
    type == TYPES[:hybrid]
  end

  def documents_have_approval?
    is_advanced? || is_hybrid?
  end

  ##
  # only show admin attentions for Advanced and Hybrid system
  ##
  def show_admin_attentions
    is_advanced? || is_hybrid?
  end

  ##
  # Create default data for new company
  ##
  def create_default_data
    Permission.create_standard_permissions(self)
    self.company_structures.create({type: 'company', name: self.name})
  end

  def logo_from_url(url)
    self.logo = open(url)
  end

  def logo_iphone4_url
    self.logo_file_name ? self.logo.url(:thumb) : ""
  end

  def self.basic_json(coll = [])
    result = []
    coll.each do |e|
      result << {
        uid: e.id.to_s,
        name: e.name,
        logo_url: e.logo_iphone4_url
      }
    end

    result
  end

  ##
  # Get Permission for standard user type
  ##
  def permission_standard
    if u_comp_perm = self.permissions.where(:code => "standard_user").first
    else
      Permission.create_standard_permissions(self)

      u_comp_perm = self.permissions.where(:code => "standard_user").first
    end

    u_comp_perm
  end

  def comp_node
    CompanyStructure.find_or_create_by({company_id: self.id, type: 'company'})
  end

  def tree_structure
    c_node = comp_node
    result = {
      id: c_node.id.to_s,
      title: self.name,
      tooltip: self.name,
      expand: true,
      key: c_node.id.to_s,
      children: Company.child_nodes(c_node)
    }
  end

  ## company, :divisions, :departments, :groups, :depots, :panels
  def self.child_nodes(object)
    result = []

    object.childs.each do |child|
      child_hash = {
        id: child.id.to_s,
        title: child.name,
        tooltip: child.name,
        expand: true,
        key: child.id.to_s
      }

      child_hash[:children] = Company.child_nodes(child)

      result << child_hash
    end

    result
  end

  ##
  # all nodes for table assign document or assign approver
  ##
  def table_structure(exclude_types = [])
    Rails.cache.fetch("/company/#{id}-#{path_updated_at}/table_structure", :expires_in => 12.hours) do
      c_node = comp_node
      result = []
      
      result << {
        type: c_node.type,
        children: [{
          id: c_node.id.to_s,
          title: self.name,
          tooltip: self.name,
          key: c_node.id.to_s,
          path: c_node.path,
          child_ids: (c_node.child_ids || [])
        }]
      } unless exclude_types.include?(c_node.type)

      types = STRUCTURES.keys.map { |e| e.to_s }
      types.delete("company")

      types.each do |type|
        next if exclude_types.include?(type)

        type_node = {
          parent_type: STRUCTURES[type.to_sym][:parent],
          type: type,
          children: []
        }
        self.company_structures.where(type: type).order([[:name, :asc]]).each do |node|
          type_node[:children] << {
            id: node.id.to_s,
            title: node.name,
            tooltip: node.name,
            key: node.id.to_s,
            path: node.path,
            child_ids: (node.child_ids || [])
          }
        end

        result << type_node if type_node[:children].length > 0
      end
      
      result
    end
  end

  ##
  # [
  #   [
  #     {name: "company name", id: comp_node_id}, {name: "devision name", id: devision_node_id} .. 
  #   ],
  #   []
  # ]
  ##
  def all_paths
    Rails.cache.fetch("/company/#{id}-#{path_updated_at}/all_paths", :expires_in => 12.hours) do
      result = []
      com_path = [{name: self.name, id: comp_node.id.to_s}]

      comp_node.childs.each do |div|
        div_path = com_path.dup

        div_path << {name: div.name, id: div.id.to_s}

        if div.child_ids.length == 0
          result << div_path
        else
          div.childs.each do |depart|
            depart_path = div_path.dup

            depart_path << {name: depart.name, id: depart.id.to_s}

            if depart.child_ids.length == 0
              result << depart_path
            else
              depart.childs.each do |group|
                group_path = depart_path.dup

                group_path << {name: group.name, id: group.id.to_s}

                if group.child_ids.length == 0
                  result << group_path
                else
                  group.childs.each do |depot|
                    depot_path = group_path.dup

                    depot_path << {name: depot.name, id: depot.id.to_s}

                    if depot.child_ids.length == 0
                      result << depot_path
                    else
                      depot.childs.each do |panel|
                        panel_path = depot_path.dup

                        panel_path << {name: panel.name, id: panel.id.to_s}

                        result << panel_path
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end

      result
    end
  end

  #{
  #    path_id => path_name
  # }
  # "comp_node_id > devision_node_id > 54b4753c5043311201330200 > 54b475495043311201360200 > 54b4754f5043311201380200" => "Standard > division 3 > af fsrer er e > fsdf er we rwe > cvvx vc x"
  def all_paths_hash
    Rails.cache.fetch("/company/#{id}-#{path_updated_at}/all_paths_hash", :expires_in => 12.hours) do
      result = {}
      all_paths.each do |path|
        path_name = []
        path_id = []

        path.each do |e|
          path_name << e[:name]
          path_id << e[:id]
        end

        name_without_comp = path_name.join(Company::NODE_SEPARATOR).gsub("#{name}#{Company::NODE_SEPARATOR}", "")

        result[path_id.join(Company::NODE_SEPARATOR)] = name_without_comp
      end

      result
    end
  end

  ##
  # Get all paths of organisation for Add/Edit User form
  # @return: Array: [[name, id], [name, id]]
  ##
  def company_paths
    Rails.cache.fetch("/company/#{id}-#{path_updated_at}/company_paths", :expires_in => 12.hours) do
      result = []
      all_paths.each do |path|
        path_arr = []
        path_name = []
        path_id = []
        path.each do |e|
          path_name << e[:name]
          path_id << e[:id]
        end

        name_without_comp = path_name.join(Company::NODE_SEPARATOR).gsub("#{name}#{Company::NODE_SEPARATOR}", "")

        path_arr = [name_without_comp, path_id.join(Company::NODE_SEPARATOR)]

        result << path_arr
      end

      result
    end
  end

  ##
  # Check approver for each area in Advanced and Hybrid system
  # just check in areas that have active user
  ##
  def check_approver
    admin_attentions.destroy_all

    return {} unless show_admin_attentions

    paths = all_paths_hash

    approvers_data = user_companies.approvers.pluck(:approver_path_ids)

    paths_has_approver = []
    approvers_data.each do |e|
      paths_has_approver.concat(e)
    end
    paths_has_approver.uniq!

    active_user_ids = users.active.pluck(:id)
    paths_has_active_user = user_companies.where(:user_id.in => active_user_ids).pluck(:company_path_ids)
    paths_has_active_user.uniq!

    paths_need_check = paths_has_active_user - paths_has_approver

    return {} if paths_need_check.blank?

    comp_nodes = STRUCTURES.keys.map { |e| e.to_s }
    admin_ids = user_companies.admins.pluck(:user_id)

    path_miss_approver = {}
    paths_need_check.each do |path_id|
      
      next unless paths[path_id]

      nodes = paths[path_id].split(Company::NODE_SEPARATOR)
      lastest_type = comp_nodes[nodes.length - 1]
      path_miss_approver[path_id] = {
        all_path_name: paths[path_id],
        lastest_name: nodes.last,
        lastest_type: lastest_type
      }

      aa = admin_attentions.create({all_path_ids: path_id, lastest_type: lastest_type})
      if aa.valid?
        admin_ids.each do |a_id|
          noti = Notification.find_or_initialize_by({user_id: a_id, company_id: self.id, type: Notification::TYPES[:need_approver][:code], 
            path_ids: path_id, lastest_type: lastest_type})

          noti.created_at = Time.now.utc
          noti.save
        end
      end
    end

    path_miss_approver
  end

  ##
  # If company is set to Approvals, check each day if there are any parts of the organisation that do not have an Approver
  ##
  def self.check_approver
    Company.where(:type.in => [TYPES[:advanced], TYPES[:hybrid]]).each do |comp|
      comp.check_approver
    end
  end

  def self.check_trial_status
    Company.where(:is_trial => true, :trial_expiry.lte => Time.now.utc).each do |comp|
      # comp.is_trial = false
      # comp.trial_expiry = nil
      comp.active = false
      comp.save
    end
  end

  def admin_users
    admin_ids = user_companies.admins.pluck(:user_id)

    users.where(:id.in => admin_ids)
  end

  ##
  # Get logs of a company
  ##
  def logs
    ActivityLog.all.with(collection: "#{self.id}_activity_logs")
  end

  ##
  # create logs of document in a company
  # log_hash = {user: user_id, target_document_id, target_user_id, action: ActivityLog::ACTIONS[:unfavourite_document]}
  ##
  def create_logs(log_hash)
    puts "---create_logs for company #{self.id} #{self.name}---"
    puts log_hash

    ActivityLog.with(collection: "#{self.id}_activity_logs").create(log_hash)
  end

  def standard_permissions
    if is_standard?
      permissions.standard.where(:code.ne => Permission::STANDARD_PERMISSIONS[:approver_user][:code])
    else
      permissions.standard
    end
  end

  ##
  # Manual generate invoice for a company in current month
  ##
  def generate_invoice
    CompanyService.monthly_payment_for_a_company(self, Time.now.utc.advance(months: -1))
  end
end