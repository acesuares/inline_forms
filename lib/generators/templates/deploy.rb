set :application, "YOUR_APPLICATION_NAME"
set :repo_url, "file:///home/#{user}/git-repos/#{application}.git"
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

after "deploy:publishing", "deploy:restart"

# Restart unicorn
namespace :deploy do
  task :restart do
    invoke "unicorn:restart"
  end
end
