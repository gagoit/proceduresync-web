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
      u_comp = user.user_company(company, true)
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

          u_doc = user.company_documents(company).where({document_id: doc.id})
          is_favourited = true
          is_accountable = doc.private_for_id == user.id || doc.approved_paths.include?(u_comp["company_path_ids"])

          if u_doc.count == 0
            user.create_user_document(company, {document_id: doc.id, is_favourited: is_favourited, 
              is_accountable: is_accountable})
          else
            u_doc.update_all({is_favourited: is_favourited, is_accountable: is_accountable, updated_at: Time.now.utc})
          end
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
      u_comp = user.user_company(company, true)
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

          u_doc = user.company_documents(company).where({document_id: doc.id})
          is_favourited = false
          is_accountable = doc.private_for_id == user.id || doc.approved_paths.include?(u_comp["company_path_ids"])

          if u_doc.count == 0
            user.create_user_document(company, {document_id: doc.id, is_favourited: is_favourited, 
              is_accountable: is_accountable})
          else
            u_doc.update_all({is_favourited: is_favourited, is_accountable: is_accountable, updated_at: Time.now.utc})
          end
        else
          
        end

        doc_ids << doc.id
      end

      NotificationService.delay(queue: "notification_and_convert_doc").documents_have_changed_meta_data([user.id], doc_ids)
    end
  end
end