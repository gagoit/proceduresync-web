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

def delayed_job_monitoring(app, default, w, id, has_queue = true)
  name = app + "-delayed_job-#{id}"
  default.with(w, :name => name, :group => app)
  
  param_str = "-i #{id}"
  param_str << " --queue=#{id}" if has_queue

  w.start = "RAILS_ENV=production; " +  default.bundle_cmd("#{default[:root]}/current/bin/delayed_job #{param_str} start")
  w.stop =  "RAILS_ENV=production; " + default.bundle_cmd("#{default[:root]}/current/bin/delayed_job stop #{param_str}")
  w.restart =  "RAILS_ENV=production; " + default.bundle_cmd("#{default[:root]}/current/bin/delayed_job restart #{param_str}")

  w.start_grace = 30.seconds
  w.restart_grace = 30.seconds
  w.stop_grace = 30.seconds

  w.log = "#{default[:root]}/shared/log/god_delayed_job.log"
  w.pid_file = "#{default[:root]}/shared/pids/delayed_job.#{id}.pid"

  w.behavior(:clean_pid_file)
  w.interval = 30.seconds

  w.start_if do |start|
    start.condition(:process_running) do |c|
      c.interval = 20.seconds
      c.running = false
    end
  end

  w.restart_if do |restart|
    restart.condition(:memory_usage) do |c|
      c.above = 3000.megabytes
      c.times = 5
    end
  end

  w.lifecycle do |on|
    # Handle edge cases where deamon
    # can't start for some reason
    on.condition(:flapping) do |c|
      c.to_state = [:start, :restart] # If God tries to start or restart
      c.times = 5                     # five times
      c.within = 5.minute             # within five minutes
      c.transition = :unmonitored     # we want to stop monitoring
      c.retry_in = 10.minutes         # for 10 minutes and monitor again
      c.retry_times = 5               # we'll loop over this five times
      c.retry_within = 2.hours        # and give up if flapping occured five times in two hours
    end
  end
end

God.watch do |w| 
  delayed_job_monitoring(app, default, w, "update_data")
end

God.watch do |w| 
  delayed_job_monitoring(app, default, w, "notification_and_convert_doc")
end

God.watch do |w| 
  delayed_job_monitoring(app, default, w, "other", false)
end