require "rvm"

if RVM.current && ENV["skiprvm"] != "true"
  RVM.chdir(File.expand_path(".")) do
    say "Working directory is #{`pwd`}"
    RVM.use_from_path! "."
    rvm_gemset = %x[rvm current]
    say "RVM GEMSET is now #{rvm_gemset}"
    say "Installing using gemset : #{RVM.current.environment_name}", :green
  end
else
  say "Installing without RVM", :green
end

apply(File.join(__dir__, "installer_core.rb"))
