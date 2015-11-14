##
# Without callback of active record when do an action
##
module ActiveSupport::Callbacks::ClassMethods
  def without_callback(*args, &block)
    skip_callback(*args)
    result = yield
    set_callback(*args)
    result
  end
end