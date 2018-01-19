class Companies::GetSectionsHaveNoReference

  def self.call company_id
    begin
      company = Company.find(company_id)
      sections_have_no_reference = []

      company.all_paths_hash.each do |path, path_name|
        if (company.user_companies.any_of({:company_path_ids => path}, {:approver_path_ids.in => [path]}, {:supervisor_path_ids.in => [path]}).size > 0) || 
            ( company.documents.where(:belongs_to_paths.in => [path]).size > 0 )

          # Has reference
        else
          sections_have_no_reference << {path => path_name}
        end
      end

      sections_have_no_reference
    rescue Exception => e
      []
    end
  end
end