module BoxView
  module Models
    class DocumentSession < Base

    	def assets_url
        return nil if self.id.nil?
        "https://view-api.box.com/1/sessions/#{self.id}/assets"
      end
    end
  end
end