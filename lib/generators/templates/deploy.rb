set :application, ENV['DEPLOY_APPLICATION']
set :repo_url, ENV['DEPLO_REPO_URL']
set :bundle_binstubs, nil

# Default deploy_to directory is /var/www/my_app_name
set :deploy_to, "/var/www/ror/#{application}"

# Default value for :linked_files is []
set :linked_files, fetch(:linked_files, [])
  .push("config/database.yml", "config/secrets.yml")
# Default value for linked_dirs is []
set :linked_dirs, fetch(:linked_dirs, [])
  .push("log", "tmp/pids", "tmp/cache", "tmp/sockets", "public/system", "vendor/bundle")

# Default value for keep_releases is 5
set :keep_releases, 5

before 'deploy:check', 'figaro:upload'
after "deploy:publishing", "deploy:restart"

# Restart unicorn
namespace :deploy do
  task :restart do
    invoke "unicorn:restart"
  end

  desc "Zero-downtime restart of Unicorn"
  task :zero_restart, :except => { :no_release => true } do
    run "kill -s USR2 `cat #{shared_path}/pids/unicorn.pid`"
  end

  desc "Downtime restart of Unicorn"
  task :restart, :except => { :no_release => true } do
    run "kill -s KILL `cat #{shared_path}/pids/unicorn.pid`"
    sleep 10
    run "rvm rvmrc trust #{current_release}"
    run "cd #{current_path} ; bundle exec r200_unicorn -c #{current_path}/config/unicorn.rb -D -E production"
  end


  desc "Start unicorn"
  task :start, :except => { :no_release => true } do
    run "rvm rvmrc trust #{current_release}"
    run "cd #{current_path} ; bundle exec r200_unicorn -c #{current_path}/config/unicorn.rb -D -E production"
  end

  desc "Stop unicorn"
  task :stop, :except => { :no_release => true } do
    run "kill -s QUIT `cat #{shared_path}/pids/unicorn.pid`"
  end

  desc "Kill unicorn"
  task :kill, :except => { :no_release => true } do
    run "kill -s KILL `cat #{shared_path}/pids/unicorn.pid`"
  end

  desc "Fix Stuff."
  task :fix_stuff do
    run "cd #{shared_path} && mkdir -p log"
    run "cd #{shared_path} && mkdir -p sockets"
    run "ln -s #{shared_path}/sockets #{release_path}/tmp/sockets"
    run "cd #{shared_path} && mkdir -p uploads"
    run "ln -s #{shared_path}/uploads #{release_path}/public/uploads"
  end
end

# Uploads secrets.yml, database.yml and application.yml files
namespace :figaro do
  task :upload do
    on roles(:all) do
      execute "mkdir -p #{shared_path}/config"

      upload! 'config/secrets.yml', "#{shared_path}/config/secrets.yml"
      upload! 'config/database.yml', "#{shared_path}/config/database.yml"
      upload! 'config/application.yml', "#{shared_path}/config/application.yml"
    end
  end
end
