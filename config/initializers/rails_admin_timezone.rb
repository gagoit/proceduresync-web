# rails_admin.rb
# https://gist.github.com/jackdesert/7090731

require 'rails_admin/config/fields/base'

module RailsAdmin
  module Config
    module Fields
      module Types
        class Datetime < RailsAdmin::Config::Fields::Base
          def value
            value_in_default_time_zone = bindings[:object].send(name)
            return nil if value_in_default_time_zone.nil?
            pacific_time_zone = ActiveSupport::TimeZone.new('Melbourne')
            value_in_default_time_zone.in_time_zone(pacific_time_zone)
          end
        end
      end
    end
  end
end