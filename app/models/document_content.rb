##
# Store the content of current version of each document
# Used to search document
##
class DocumentContent
  include Mongoid::Document
  include Mongoid::Timestamps
  # include Mongoid::Search

  belongs_to :company
  belongs_to :document

  # search_in :document => [:title, :doc_id, :created_time, :expiry, :category_name, :curr_version]

  field :title, type: String, default: ""
  field :pages, type: Array, default: []
  field :_keywords, type: Array, default: []

  field :doc_id, type: String, default: ""

  scope :by_company, ->(comp_id) {where(company_id: comp_id)}

  index({pages: "text", title: "text", doc_id: "text", :'_keywords' => "text", company_id: 1}, {
      weights: {
        title: 100,
        doc_id: 100,
        pages: 1,
        _keywords: 20
      }
    })

  index({document_id: 1})

  ##
  # Text search on content of document
  ##
  def self.search(comp_id, text)
    begin
      result = DocumentContent.where("$text" => {"$search" => text}, company_id: comp_id)
    rescue Exception => e
      puts e.message
      DocumentContent.where(document_id: nil)
    end
  end

  def self.mongo_search(filter_doc_ids, text, page = nil, per_page = nil)
    basic_query = [
          { "$match" => { "$text" => { "$search" => text }, "document_id" => {"$in" => filter_doc_ids} } },
          { "$sort" => { score: { "$meta" => "textScore" }, created_at: 1 } },
          { "$project" => {document_id: 1, title: 1, score: { "$meta" => "textScore" } } }
        ]

    paging_query = basic_query.dup

    if page && per_page
      paging_query << { "$skip" => (page - 1) * per_page }
      paging_query << { "$limit" => per_page }
    end

    session = Mongoid::Clients.default
    d_c = session["document_contents"]

    begin
      result = d_c.aggregate(paging_query)
      total_count = d_c.aggregate(basic_query).count

      return result, total_count
    rescue Exception => e
      puts e.message
      return [], 0
    end
  end

  ##
  # Create text indexes
  ##
  def self.create_text_indexes
    # session = Mongoid::Clients.default

    # d_c = session["document_contents"]

    # d_c.indexes.drop

    # d_c.indexes.create({document_id: 1})

    # d_c.indexes.create({pages: "text", title: "text", doc_id: "text", :'_keywords' => "text", company_id: 1}, {
    #   weights: {
    #     title: 100,
    #     doc_id: 100,
    #     pages: 1,
    #     _keywords: 20
    #   }
    # })

    self.create_indexes
  end
end