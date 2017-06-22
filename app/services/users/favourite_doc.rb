require 'singleton'

module Users
  class FavouriteDoc
    include Singleton

    def initialize
      
    end

    ##
    # User add documents to favourite list
    ##
    def add_favourites(user, company, params)
      ids = params[:ids] || "all"
      documents, total_count = Document.get_all(user, company, {page: nil, per_page: nil, search: (params[:search] || ''), sort_by: [[:title, :asc]], 
          filter: (params[:filter] || "all"), category_id: params[:filter_category_id], types: (params[:document_types] || "all"), ids: ids, order_by_ranking: params[:order_by_ranking]})

      action_time = Time.now.utc
      doc_ids = []
      act_log_hash = {action: ActivityLog::ACTIONS[:favourite_document]}

      documents.only(%w( _id expiry active private_for_id approved_paths )).each do |doc|
        next if doc.is_expiried

        if user.favourited_doc?(doc)
          
        else
          user.favourite_document_ids << doc.id
          user.save

          #Create log
          act_log_hash[:target_document_id] = doc.id
          act_log_hash[:action_time] = action_time
          user.create_logs(company, act_log_hash)

          UserDocuments::UpdateStatus.call(company, user, doc, {is_favourited: true})
        end

        doc_ids << doc.id
      end

      NotificationService.delay(queue: "notification_and_convert_doc").documents_have_changed_meta_data([user.id], doc_ids)
    end

    ##
    # User add documents to favourite list
    ##
    def remove_favourites(user, company, params)
      ids = params[:ids] || "all"
      documents, total_count = Document.get_all(user, company, {page: nil, per_page: nil, search: (params[:search] || ''), sort_by: [[:title, :asc]], 
          filter: (params[:filter] || "all"), category_id: params[:filter_category_id], types: (params[:document_types] || "all"), ids: ids, order_by_ranking: params[:order_by_ranking]})

      action_time = Time.now.utc
      doc_ids = []
      act_log_hash = {action: ActivityLog::ACTIONS[:unfavourite_document]}

      documents.only(%w( _id expiry active private_for_id approved_paths )).each do |doc|
        next if doc.is_expiried

        if user.favourited_doc?(doc)
          user.favourite_document_ids.delete(doc.id)
          user.save

          #Create log
          act_log_hash[:target_document_id] = doc.id
          act_log_hash[:action_time] = action_time
          user.create_logs(company, act_log_hash)

          UserDocuments::UpdateStatus.call(company, user, doc, {is_favourited: false})
        else
          
        end

        doc_ids << doc.id
      end

      NotificationService.delay(queue: "notification_and_convert_doc").documents_have_changed_meta_data([user.id], doc_ids)
    end
  end
end