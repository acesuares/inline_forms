# DEPLOY_DIRECTORY (see config/deploy.rb) has to be in the environment Unicorn
# starts in.
app_path = "#{ENV.fetch("DEPLOY_DIRECTORY")}/current"
working_directory app_path

pid "#{app_path}/tmp/pids/unicorn.pid"

stderr_path "#{app_path}/log/unicorn.err.log"
stdout_path "#{app_path}/log/unicorn.out.log"

worker_processes 3
timeout 30
preload_app true

listen "#{app_path}/tmp/sockets/unicorn.sock", backlog: 64

before_exec do |_|
  ENV["BUNDLE_GEMFILE"] = File.join(app_path, "Gemfile")
end

before_fork do |server, worker|
  defined?(ActiveRecord::Base) and ActiveRecord::Base.connection_pool.disconnect!

  old_pid = "#{app_path}/tmp/pids/unicorn.pid.oldbin"

  if File.exist?(old_pid) && server.pid != old_pid
    begin
      Process.kill("QUIT", File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
    end
  end
end

after_fork do |server, worker|
  defined?(ActiveRecord::Base) and ActiveRecord::Base.establish_connection
end
