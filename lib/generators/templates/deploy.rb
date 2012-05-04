# -*- encoding : utf-8 -*-

require "bundler/capistrano"
require "rvm/capistrano"

set :application, "YOUR_APPLICATION_NAME"
set :domain,      "YOUR_HOST_NAME"
set :user,        "YOUR_USERNAME_ON_THE_HOST"

#

set :rvm_ruby_string, ENV['GEM_HOME'].gsub(/.*\//,"") # Read from local system

set :bundle_flags,       "--deployment"

set :use_sudo,    false

set :deploy_to,   "/var/www/ror/#{application}"

set :repository,  "file:///home/#{user}/git-repos/#{application}.git"
set :local_repository, "ssh://#{user}@#{domain}/home/#{user}/git-repos/#{application}.git"
set :scm,         "git"


role :app, domain
role :web, domain
role :db,  domain, :primary => true

before :deploy do
  system "bundle install"
  system "git commit -a"
  system "git push"
end

before 'deploy:setup', 'rvm:install_rvm'
before 'deploy:setup', 'rvm:install_ruby'
after  "deploy:update_code", "deploy:fix_stuff"
after  "deploy:update_code", "deploy:precompile_assets"



namespace :deploy do
  desc "Zero-downtime restart of Unicorn"
  task :restart, :except => { :no_release => true } do
    run "kill -s USR2 `cat #{shared_path}/pids/unicorn.pid`"
  end

  desc "Start unicorn"
  task :start, :except => { :no_release => true } do
    run "rvm rvmrc trust #{current_release}"
    run "cd #{current_path} ; r193_unicorn -c config/unicorn.rb -D -E production"
  end

  desc "Stop unicorn"
  task :stop, :except => { :no_release => true } do
    run "kill -s QUIT `cat #{shared_path}/pids/unicorn.pid`"
  end

  desc "Fix Stuff."
  task :fix_stuff do
    run "cd #{shared_path} && mkdir -p log"
    run "cd #{shared_path} && mkdir -p sockets"
    run "ln -s #{shared_path}/sockets #{release_path}/tmp/sockets"
    raise "Rails environment not set" unless rails_env
    run "cd #{release_path} && RAILS_ENV=#{rails_env} bundle exec rails g ckeditor:install "
  end


  desc "Compile all the assets named in config.assets.precompile."
  task :precompile_assets do
    raise "Rails environment not set" unless rails_env
    task = "assets:precompile"
    run "cd #{release_path} && bundle exec rake #{task} RAILS_ENV=#{rails_env}"
  end

end
