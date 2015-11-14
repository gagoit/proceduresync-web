require 'tzinfo'
require "active_support/core_ext"

module TimeZoneExt
  def strptime(date, format)
    # if format =~ /%z/i
    #   DateTime.strptime(date, format).in_time_zone
    # else
    #   DateTime.strptime("#{date} zone#{formatted_offset}", "#{format} zone%z").in_time_zone
    # end
    time = DateTime.strptime(date, format)
    parse(time.strftime("%Y-%m-%d %H:%M:%S"))
  end
end

ActiveSupport::TimeZone.send :include, TimeZoneExt