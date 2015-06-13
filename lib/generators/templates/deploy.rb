# -*- encoding : utf-8 -*-

require "bundler/capistrano"
require "rvm/capistrano"

load 'deploy/assets'

set :rvm_ruby_string, ENV['GEM_HOME'].gsub(/.*\//,"") # Read from local system
set :rvm_install_ruby_params, '--1.9'      # for jruby/rbx default to 1.9 mode https://github.com/wayneeseguin/rvm-capistrano/commit/663252851a9d6294439a9b501cebe66f8c3150f7

set :application, "YOUR_APPLICATION_NAME"
set :domain,      "YOUR_HOST_NAME"
set :user,        "YOUR_USERNAME_ON_THE_HOST"

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
before  "deploy:assets:precompile", "deploy:fix_stuff"


namespace :deploy do
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
