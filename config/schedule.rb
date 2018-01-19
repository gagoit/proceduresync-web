# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end

# Learn more: http://github.com/javan/whenever

every 1.day, :at => '0:00 am' do
  runner "Company.check_approver; Company.check_trial_status"
end

#Each 5 minutes
every "*/5 * * * *" do
  runner "Document.check_effective_documents; Document.check_invalid_documents;"
end

every 2.minutes do
  runner "Document.check_and_download_not_done_documents;"
end

every 1.hours do
	runner "Notification.sent_daily_approval_email"
end

every '0 1 1 * *' do
  runner "CompanyService.monthly_payment"
end

every 1.day, :at => '10:00 pm' do
  runner "ReportService.auto_emailed_reports('daily')"
end

# weekly
every :monday, :at => '9:00 pm' do 
  runner "ReportService.auto_emailed_reports('weekly')"
end

#first day of month: monthly
every '0 20 1 * *' do
  runner "ReportService.auto_emailed_reports('monthly')"
end

#15th of month: fortnightly
every '30 20 15 * *' do
  runner "ReportService.auto_emailed_reports('fortnightly')"
end

every 1.hours do
  rake "update_not_accountable_paths"
end

every 6.minutes do
  runner "User.update_docs_count"
end