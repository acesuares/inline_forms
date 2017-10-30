set :user, ENV["DEPLOY_USER"]
set :deploy_via, :remote_cache
set :conditionally_migrate, true
set :rails_env, "production"

# Server IP
server ENV["DEPLOY_HOST"], user: fetch(:user), port: fetch(:port), roles: %w(web app db)
