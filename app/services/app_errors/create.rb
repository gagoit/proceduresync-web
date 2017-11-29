class AppErrors::Create < BaseService
  
  def self.call company_id, type, message, note="", status="new"
    begin
      AppError.create!({
        company_id: company_id,
        type: type,
        message: message,
        note: note,
        status: status
      })

      BaseService.notify_or_ignore_error(Exception.new(message))
    rescue Exception => e
      BaseService.notify_or_ignore_error(Exception.new("[AppErrors::Create.call][company_id: #{company_id}][type: #{type}][message: #{message}][note: #{note}][status: #{status}] Exception: #{e.message} | At: #{get_first_line_num_in_exception(e)}"))
    end
  end
end