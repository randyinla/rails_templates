# base_template.rb
#
# gem(name, options = {})
# plugin(name, options = {})
# initializer(filename, data = nil, &block)
# lib() creates file in lib dir
# vendor() creates a file in vendor dir
# file() accepts a relative path from RAILS_ROOT and creates all the dis/file needed
# rakefile(filename, data = nil, &block) creates new rake file under lib/tasks
# generate(what, args) runs rails generator with given args. 
# run(command) executes arbitrary command.
# rake(command, options = {}) for things like rake "db:migrate"
# route(routing_code) adds rounting entry to config/routes.rb ie. route "map.root :controller => :person"
# inside('dir') do; allows running of a command within the specified dir; end
# ask(question) get feedback from user and use within templates. ie.answer = ask("what to call a user?")
# yes?(question) do;end or no?(question)
# git(:must => "-a love")


run 'echo Author: Randy Walker > README'
run 'rm public/index.html'
run 'rm doc/README_FOR_APP'
run 'rm public/favicon.ico'
run 'rm public/robots.txt'

plugin 'link_to_with_prompt', :git => 'http://github.com/bhedana/link_to_with_prompt/'
plugin 'link_to_remote_with_prompt', :git => 'git://github.com/randyinla/link_to_remote_with_prompt.git'

# BDD
if yes?('Include BDD?')
  plugin 'rspec', :git => 'git://github.com/dchelimsky/rspec.git'
  plugin 'rspec-rails', :git => 'git://github.com/dchelimsky/rspec-rails.git'
  plugin 'cucumber', :git => 'git://github.com/aslakhellesoy/cucumber.git'
  generate :rspec
end

# Pagination
if yes?('Include pagination?')
  plugin 'will_paginate', :git => 'git://github.com/mislav/will_paginate'
end

# Restful User Authentication
if yes?('Include Restful User Authentication?')
  plugin 'restful-authentication', :git => 'git://github.com/technoweenie/restful-authentication.git'
  plugin 'role_requirement', :git => 'git://github.com/timcharper/role_requirement.git'
  plugin 'open_id_authentication', :git => 'git://github.com/rails/open_id_authentication.git'
  gem 'ruby-openid', :lib => 'openid'
  gem 'rubyist-aasm', :lib => 'aasm', :source => 'http://gems.github.com'
  generate('authenticated', 'user sessions --rspec --include-activation --stateful')
end

# Exception Notification
if yes?('Include email-based Exception Notifier?')
  plugin 'exception_notifier', :git => 'git://github.com/rails/exception_notification.git'
end

# JQuery
if yes?('Install JQuery?')
  run 'curl -L http://jqueryjs.googlecode.com/files/jquery-1.3.2.min.js > public/javascripts/jquery.js'
end

# gems:install
if yes?('Run gems:install?')
  rake("gems:install", :sudo => true)
end

# local git repo
if yes?('Create local git repository for app?')
  git :init
  run "touch tmp/.gitignore log/.gitignore vendor/.gitignore"
  run "cp config/database.yml config/example_database.yml"
  file ".gitignore", <<-END
  .DS_Store
  log/*.log
  db/schema.rb
  tmp/**/*
  config/database.yml
  db/*.sqlite3
  END
  git :add => ".", :commit => "-m 'initial commit'"
end