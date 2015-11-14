 require 'zip/zip'
require 'weakref'
require 'paperclip'

module Paperclip
  class ZipEntryAdapter < StringioAdapter
    def initialize(target)
      target.instance_eval do
        def original_filename
          to_s
        end
      end

      super(target)
    end

    def copy_to_tempfile(src)
      content = WeakRef.new(src.get_input_stream.read)
      destination.write(content)
      destination.rewind

      # cleanup memory that we spent for reading zip entry.
       destination
    end
  end
end

Paperclip.io_adapters.register Paperclip::ZipEntryAdapter do |target|
  Zip::ZipEntry === target
end