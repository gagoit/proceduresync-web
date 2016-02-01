desc "Update not_accountable_paths"
task :update_not_accountable_paths => :environment do
  DocumentService.update_not_accountable_paths
end
