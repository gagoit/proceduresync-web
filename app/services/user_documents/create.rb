class UserDocuments::Create

  def self.call company, u_docs = []
    return if u_docs.blank?

    func = "function(n){return db['#{company.id}_user_documents'].insert(n);}"
    MyMongo.database.command({ eval: func, args: [u_docs]})
  end

end