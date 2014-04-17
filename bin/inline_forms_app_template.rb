require 'rvm'

if RVM.current && ENV['skiprvm'] !='true'
  rvm_version = "#{ENV['ruby_version']}@#{app_name}"
  RVM.chdir "../#{app_name}" do
    say "Working directory is #{`pwd`}"
    RVM.use_from_path! '.'
    rvm_gemset = %x[rvm current]
    say "RVM GEMSET is now #{rvm_gemset}"
    say "Installing using gemset : #{RVM.current}", :green
  end
else
  say "Installing without RVM", :green
end

apply(File.join(File.dirname(__FILE__), 'inline_forms_installer_core.rb'))
