app = 'proceduresync'

default = DefaultConfig.new(:root => "/home/ubuntu/#{app}")

God.watch do |w|
  name = app + '-thin'

  default.with(w, :name => name, :group => app)

  w.start    = default.bundle_cmd "thin start -d -S /tmp/#{app}.sock -e production"
  w.pid_file = "#{default[:root]}/shared/pids/thin.pid"

  w.behavior(:clean_pid_file)

  w.start_if do |start|
    start.condition(:process_running) do |c|
      c.interval = 20.seconds
      c.running = false
    end
  end
  
end

God.watch do |w| 
  name = app + '-delayed_job'
  default.with(w, :name => name, :group => app)
  
  w.start = "RAILS_ENV=production; " +  default.bundle_cmd("#{default[:root]}/current/bin/delayed_job start> /tmp/delay_job.out")
  w.stop =  "RAILS_ENV=production; " + default.bundle_cmd("#{default[:root]}/current/bin/delayed_job stop")
  w.log = "#{default[:root]}/shared/log/god_delayed_job.log"
  w.start_grace = 15.seconds 
  w.restart_grace = 15.seconds 
  w.pid_file = "#{default[:root]}/shared/pids/delayed_job.pid"
end