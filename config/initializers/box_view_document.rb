#https://github.com/clio/box_view/blob/master/lib/box_view/api/document.rb
#Enable non_svg params when upload document

module BoxView
  module Api
    class Document < Base

      def upload(url, name, non_svg = true)
        data_item(session.post(endpoint_url, { url: url, name: name, non_svg: non_svg }.to_json), session)
      end

      

    end
  end
end

module BoxView
  module Models
    class Document < Base

      def document_session(params = {})
      	base_params = {document_id: self.id}
      	base_params.merge!(params)

        @document_session ||= BoxView::Api::DocumentSession.new(session).create(base_params)
      end

    end
  end
end