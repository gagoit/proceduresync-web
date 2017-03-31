module Requests
  module JsonHelpers
    def json
      unless @json
        puts JSON.parse(response.body)
      end
      @json ||= JSON.parse(response.body)

      @json
    end
  end
end