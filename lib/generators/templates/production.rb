set :user, "root"
set :deploy_via, :remote_cache
set :conditionally_migrate, true
set :rails_env, "production"

# Server IP
server "165.227.102.11", user: fetch(:user), port: fetch(:port), roles: %w(web app db)
