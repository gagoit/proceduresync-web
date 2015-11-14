class PushNotification
  include Mongoid::Document
  include Mongoid::Timestamps::Created

  field :devices, type: Array
  field :tags, type: String
  field :alert, type: String

  field :badge, type: Integer
  field :instant, type: Boolean
  field :sound, type: String

  field :payload, type: Hash, default: {}
  field :access_token, type: String

  #Type of push notification
  field :type, type: String


  def to_json(user)
    tmp_json = {
      :instant=> instant, 
      :alert=> alert, 
      :sound=> sound 
    }

    tmp_json.merge!(payload)

    if (doc_ids = tmp_json[:document_ids]) || (doc_ids = tmp_json["document_ids"])
      docs = Document.where(:id.in => doc_ids)

      tmp_json[:documents] = Document.to_json(user, docs, {show_is_unread: true})

      if type == "document_is_invalid" || type == "remove_accountable"
        tmp_json[:documents].map! { |e| e.merge({is_inactive: true}) }
      end
    end

    tmp_json
  end
end