# -*- encoding : utf-8 -*-
require "bundler/capistrano"

set :rvm_ruby_string, ENV['GEM_HOME'].gsub(/.*\//,"") # Read from local system

require "rvm/capistrano"

set :bundle_flags,       "--deployment"

set :use_sudo,    false

set :application, "iDesignBack"
set :domain,      "ror.suares.com"

set :deploy_to,   "/var/www/ror/#{application}"

set :repository,  "file:///home/capdeploy/git-repos/#{application}.git"
set :local_repository, "ssh://capdeploy@#{domain}/home/capdeploy/git-repos/#{application}.git"
set :scm,         "git"

set :user,        "capdeploy"

role :app, domain
role :web, domain
role :db,  domain, :primary => true

before :deploy do
  system "bundle install"
#  system "bundle update inline_forms"
  system "git commit -a"
  system "git push"
end

after "deploy:update_code", "deploy:precompile_assets"
before 'deploy:setup', 'rvm:install_rvm'
before 'deploy:setup', 'rvm:install_ruby'

namespace :deploy do
  task :start, :roles => :app do
    run "touch #{current_release}/tmp/restart.txt"
  end

  task :stop, :roles => :app do
    # Do nothing.
  end

desc "Compile all the assets named in config.assets.precompile."
task :precompile_assets do

  run "cd #{release_path}/../../shared && mkdir -p log"
  raise "Rails environment not set" unless rails_env
  task = "assets:precompile"
  run "cd #{release_path} && bundle exec rake #{task} RAILS_ENV=#{rails_env}"
end

  desc "Restart Application"
  task :restart, :roles => :app do
    run "touch #{current_release}/tmp/restart.txt"
  end
end
