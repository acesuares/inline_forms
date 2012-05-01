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
  task :start, :roles => :app do
    run "touch #{current_release}/tmp/restart.txt"
  end

  task :stop, :roles => :app do
    # Do nothing.
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

  desc "Restart Application"
  task :restart, :roles => :app do
    run "touch #{current_release}/tmp/restart.txt"
  end
end
