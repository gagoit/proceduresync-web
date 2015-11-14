module Requests
  module JsonHelpers
    def json
      @json ||= JSON.parse(response.body)
      puts @json

      @json
    end
  end
end