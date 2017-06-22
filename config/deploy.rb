# config valid only for Capistrano 3.1
lock '3.1.0'

set :application, 'proceduresync'
set :repo_url, 'git@github.com:Proceduresync/proceduresync-web.git'

# Default branch is :master
set :branch, :master

# Default deploy_to directory is /var/www/my_app
set :deploy_to, '/home/ubuntu/proceduresync'
set :pty, true

# Default value for :scm is :git
# set :scm, :git

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
# set :log_level, :debug

# Default value for :pty is false

# Default value for :linked_files is []
# set :linked_files, %w{config/database.yml}

# Default value for linked_dirs is []
# set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system}

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
set :keep_releases, 15

set :rbenv_type, :user # or :system, depends on your rbenv setup
# set :rbenv_repository, 'https://github.com/sstephenson/rbenv.git'
# set :rbenv_ruby_version, '2.0.0-p195'
set :rbenv_ruby, '2.1.5'
set :rbenv_path, "/opt/rbenv"
set :rbenv_map_bins, %w{rake gem bundle ruby rails}
#
set :use_sudo, true
# set :rvm_type, :user                     # Defaults to: :auto
# set :rvm_ruby_version, '2.1.1'      # Defaults to: 'default'

#For Delayed::Job
# https://github.com/collectiveidea/delayed_job/wiki/Delayed-Job-tasks-for-Capistrano-3
set :rails_env, "production" #added for delayed job

#set :delayed_job_server_role, :worker
# set :delayed_job_args, [" -i update_data --queue=update_data", " -i notification_and_convert_doc --queue=notification_and_convert_doc", " -i other"]

namespace :deploy do

  desc 'Restart application'

  task :bundle_install do
    on roles(:app) do
      within current_path do    
        with rails_env: fetch(:rails_env) do
          execute :bundle, :install, "--path #{shared_path}/bundle --deployment --quiet --without development test".to_sym, raise_on_non_zero_exit: false
        end
      end
    end
  end

  # Stop rails s (thin)
  task :stop_rails do
    on roles(:app) do
      within current_path do    
        with rails_env: fetch(:rails_env) do
          execute :bundle, :exec, "thin stop -P #{shared_path}/pids/thin.pid".to_sym, raise_on_non_zero_exit: false
        end
      end
    end
  end

  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      # Your restart mechanism here, for example:
      # execute :touch, release_path.join('tmp/restart.txt')
      within current_path do    
        with rails_env: fetch(:rails_env) do
          execute :bundle, :exec, "thin start -d -S /tmp/#{fetch(:application)}.sock -e production".to_sym, raise_on_non_zero_exit: false
        end
      end
    end
  end

  task :backup_db do
    on roles(:app) do
      info "Backup database before deploy"
      execute "/bin/bash /home/ubuntu/mongodb-backup/#{fetch(:application)}", raise_on_non_zero_exit: false
    end
  end

  desc "Change HTML Symlink to relative path"
  task :create_symlink do
    on roles(:app) do

      info "Create symlink for mongoid.yml"
      execute "rm #{current_path}/config/mongoid.yml && ln -s #{shared_path}/config/mongoid.yml #{current_path}/config/mongoid.yml"

      info "Create symlink for assets"
      execute "mkdir -pv  #{shared_path}/assets"
      execute "sudo ln -s #{shared_path}/assets #{current_path}/public/assets"

      #Link the log directory to the main log directory on /home/#{user}/logs/#{application}
      info "Create symlink for logs"
      log_location = "/home/ubuntu/logs/#{fetch(:application)}"

      execute "rm -rf #{shared_path}/log && mkdir -p #{log_location} && sudo ln -nfs #{log_location} #{shared_path}/log"
      execute "rm -rf #{current_path}/log && sudo ln -s #{shared_path}/log #{current_path}/log"

      # info "Create symlink for pids"
      # execute "mkdir -pv #{shared_path}/pids && mkdir -pv #{current_path}/tmp"
      # execute "rm -rf #{current_path}/tmp/pids && sudo ln -s #{shared_path}/pids #{current_path}/tmp/pids", raise_on_non_zero_exit: false

      # info "Create symlink for God"
      # execute "sudo ln -nfs #{current_path}/config/deploy/#{fetch(:application)}.god /etc/god/config.d/#{fetch(:application)}.god"

      info "Create symlink for Nginx"
      execute "sudo ln -nfs #{current_path}/config/deploy/nginx /etc/nginx/sites-enabled/#{fetch(:application)}"
    end
  end

  task :create_symlink_pids do
    on roles(:app) do
      info "Create symlink for pids"
      execute "mkdir -pv #{shared_path}/pids && mkdir -pv #{current_path}/tmp"
      execute "rm -rf #{current_path}/tmp/pids && sudo ln -s #{shared_path}/pids #{current_path}/tmp/pids"
    end
  end

  task :start_delayed_job do
    invoke 'delayed_job:start'
  end

  task :stop_delayed_job do
    invoke 'delayed_job:stop'
  end

end

#For app using whenever
namespace :whenever do
  desc 'Update whenever'

  task :update_crontab do
    on roles(:app) do
      # if File.exists?("#{current_path}/config/schedule.rb")
      #   execute "cd #{current_path} && bundle exec whenever --load-file config/schedule.rb --update-crontab #{fetch(:application)}", raise_on_non_zero_exit: false
      # else
      #   execute "cd #{current_path} && bundle exec whenever --update-crontab #{fetch(:application)}", raise_on_non_zero_exit: false
      # end

      within current_path do    
        with rails_env: fetch(:rails_env) do
          execute :bundle, :exec, "whenever --update-crontab #{fetch(:application)}".to_sym
        end
      end
    end
  end
end

#DelayedJob
namespace :delayed_job do

  def args
    fetch(:delayed_job_args, "")
  end

  def delayed_job_roles
    fetch(:delayed_job_server_role, :app)
  end

  desc 'Stop the delayed_job process'
  task :stop do
    on roles(delayed_job_roles) do
      within current_path do    
        with rails_env: fetch(:rails_env) do
          if args.is_a?(Array)
            args.each do |arg|
              execute :bundle, :exec, :'bin/delayed_job', arg, :stop, raise_on_non_zero_exit: false
            end
          else
            execute :bundle, :exec, :'bin/delayed_job', args, :stop, raise_on_non_zero_exit: false
          end

          execute "rm -rf #{current_path}/tmp/pids/delayed_job*", raise_on_non_zero_exit: false
        end
      end
    end
  end

  desc 'Start the delayed_job process'
  task :start do
    on roles(delayed_job_roles) do
      within current_path do
        with rails_env: fetch(:rails_env) do
          if args.is_a?(Array)
            args.each do |arg|
              execute :bundle, :exec, :'bin/delayed_job', arg, :start
            end
          else
            execute :bundle, :exec, :'bin/delayed_job', args, :start
          end
        end
      end
    end
  end

  desc 'Restart the delayed_job process'
  task :restart do
    on roles(delayed_job_roles) do
      within current_path do
        with rails_env: fetch(:rails_env) do
          if args.is_a?(Array)
            args.each do |arg|
              execute :bundle, :exec, :'bin/delayed_job', arg, :restart
            end
          else
            execute :bundle, :exec, :'bin/delayed_job', args, :restart
          end
        end
      end
    end
  end

end

## God ##
namespace :god do
  desc 'Load and restart God'

  task :stop do
    on roles(:app) do
      within current_path do
        with rails_env: fetch(:rails_env) do
          execute "sudo -i RBENV_VERSION=#{fetch(:rbenv_ruby)} god stop #{fetch(:application)}", raise_on_non_zero_exit: false
        end
      end
    end
  end

  task :restart do
    on roles(:app) do
      within current_path do
        with rails_env: fetch(:rails_env) do
          execute "sudo -i god load #{current_path}/config/deploy/#{fetch(:application)}.god"

          execute "sudo -i RBENV_VERSION=#{fetch(:rbenv_ruby)} god start #{fetch(:application)}"
        end
      end
    end
  end

end

#Assets https://github.com/capistrano/rails/blob/master/lib/capistrano/tasks/assets.rake
namespace :assets do
  task :precomplie do
    on roles(:app), in: :sequence, wait: 5 do
      within current_path do    
        with rails_env: fetch(:rails_env) do
          execute :bundle, :exec, "rake i18n:js:export".to_sym, raise_on_non_zero_exit: false
          execute :bundle, :exec, "rake assets:precompile".to_sym, raise_on_non_zero_exit: false
        end
      end
    end
  end
end

## Nginx ##
namespace :nginx do
  desc 'Load and restart Nginx'

  task :restart do
    on roles(:app) do
      within current_path do
        with rails_env: fetch(:rails_env) do
          execute "sudo service nginx reload", raise_on_non_zero_exit: false
          execute "sudo service nginx restart", raise_on_non_zero_exit: false
        end
      end
    end
  end

end

# before 'deploy:starting', 'deploy:backup_db'

after 'deploy:started', 'god:stop'

before 'deploy:finished', "deploy:create_symlink"

after 'deploy:finished', 'deploy:bundle_install'

after 'deploy:bundle_install', "assets:precomplie"

after 'assets:precomplie', 'deploy:stop_delayed_job'

after 'deploy:stop_delayed_job', 'deploy:stop_rails'

after 'deploy:stop_rails', 'deploy:create_symlink_pids'

after 'deploy:create_symlink_pids', 'deploy:restart'

after 'deploy:restart', 'deploy:start_delayed_job'

after 'deploy:start_delayed_job', 'god:restart'

after 'god:restart', 'whenever:update_crontab'

after 'whenever:update_crontab', 'nginx:restart'