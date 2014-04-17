require 'rvm'

if RVM.current && ENV['skiprvm'] !='true'
  rvm_version = "#{ENV['ruby_version']}@#{app_name}"
  RVM.chdir "../#{app_name}" do
    say "Working directory is #{`pwd`}"
    RVM.use_from_path! '.' # TODO ROYTJE FIX THIS BELOW
# Warning! PATH is not properly set up, '/home/vagrant/.rvm/gems/ruby-2.0.0-p247@MyApp/bin' is not available,
         # usually this is caused by shell initialization files - check them for 'PATH=...' entries,
         # it might also help to re-add RVM to your dotfiles: 'rvm get stable --auto-dotfiles',
         # to fix temporarily in this shell session run: 'rvm use ruby-2.0.0-p247@MyApp'.
    rvm_gemset = %x[rvm current]
    say "RVM GEMSET is now #{rvm_gemset}"
    say "Installing using gemset : #{RVM.current}", :green # TODO ROYTJE FIX THIS Installing using gemset : #<RVM::Environment:0xa319a70>
  end
else
  say "Installing without RVM", :green
end

apply(File.join(File.dirname(__FILE__), 'inline_forms_installer_core.rb'))
