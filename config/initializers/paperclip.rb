#disable spoofing protection
#https://github.com/thoughtbot/paperclip/issues/1429
require 'paperclip/media_type_spoof_detector'
module Paperclip
  class MediaTypeSpoofDetector
    def spoofed?
      false
    end
  end
end

#http://stackoverflow.com/questions/694115/why-does-ruby-open-uris-open-return-a-stringio-in-my-unit-test-but-a-fileio-in
#Fix error: when open a image url, it doesn't generate a temp file, just generate StringIO
#
#The open-uri library uses a constant to set the 10KB size limit for StringIO objects.
#You can change this setting to 0 to prevent open-uri from ever creating a StringIO object.
#Instead, this will force it to always generate a temp file.
require 'open-uri'
OpenURI::Buffer.send :remove_const, 'StringMax' if OpenURI::Buffer.const_defined?('StringMax')
OpenURI::Buffer.const_set 'StringMax', 0