class Companies::GetReferenceInfoOfSection

  def self.call company, path
    reference_info = {}

    begin
      reference_info[:users] = company.user_companies.includes(:user).where(:company_path_ids => /#{path}/)
      reference_info[:active_users] = company.user_companies.includes(:user).active.where(:company_path_ids => /#{path}/)
      reference_info[:users_count] = reference_info[:users].count
      reference_info[:active_users_count] = reference_info[:active_users].count
    rescue Exception => e
      puts "[Companies::GetReferenceInfoOfSection].call error: #{e.message}"
    end

    reference_info
  end
end