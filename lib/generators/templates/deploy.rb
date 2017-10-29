set :application, ENV['DEPLOY_APPLICATION']
set :repo_url, ENV['DEPLO_REPO_URL']
set :bundle_binstubs, nil

# Default deploy_to directory is /var/www/my_app_name
set :deploy_to, "/var/www/ror/#{fetch(:application)}"

# Default value for :linked_files is []
set :linked_files, fetch(:linked_files, [])
  .push("config/database.yml", "config/secrets.yml", "config/application.yml")
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
