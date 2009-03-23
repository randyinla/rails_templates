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
#

pswd = ask("Enter db password:")
domainurl = ask("Enter domain URL:") 
emailserver = ask("Enter email server:")
adminlogin = ask("Enter admin login:")
adminemail = ask("Enter admin email address:").gsub('@', '\\@')
app_name = "#{(run  'pwd').split('/')[-1].chomp}"
run "echo Author: Randy Walker #{Time.now()} > README"

# remove unused rails files
run 'rm public/index.html'
run 'rm doc/README_FOR_APP'
run 'rm public/favicon.ico'
run 'rm public/robots.txt'
run 'rm public/images/rails.png'

# set db password in database.yml and filter passwords from log file
run "perl -i -pe 's/password:/password: #{pswd}/' config/database.yml"
run "perl -i -pe 's/# filter_parameter_logging :password/filter_parameter_logging :password/' app/controllers/application_controller.rb"

# set some defaults
initializer 'mime_types.rb', <<-CODE
Mime::Type.register_alias "text/html", :iphone
CODE
initializer 'new_rails_defaults.rb', <<-CODE
if defined?(ActiveRecord)
  ActiveRecord::Base.include_root_in_json = false
  ActiveRecord::Base.store_full_sti_class = true
end
ActiveSupport.escape_html_entities_in_json = false
CODE
initializer 'not_nil_blank.rb', <<-CODE
class Object
  def not_nil?
    !nil?
  end
  def not_blank?
    !blank?
  end
end
CODE

# Javascript prompt available to link helpers
plugin 'link_to_with_prompt', :git => 'http://github.com/bhedana/link_to_with_prompt/'
plugin 'link_to_remote_with_prompt', :git => 'git://github.com/randyinla/link_to_remote_with_prompt.git'

# Restful User Authentication: restful_authentication, role_requirement, open_id_authentication, aasm, ra_add_ons
plugin 'restful-authentication', :git => 'git://github.com/technoweenie/restful-authentication.git'
#plugin 'role_requirement', :git => 'git://github.com/timcharper/role_requirement.git'
plugin 'open_id_authentication', :git => 'git://github.com/rails/open_id_authentication.git'
plugin 'aasm', :git => 'git://github.com/rubyist/aasm.git'
plugin 'ra_add_ons', :git => 'git://github.com/randyinla/ra_add_ons.git'
gem 'ruby-openid', :lib => 'openid'
generate('authenticated', 'user sessions --rspec --include-activation --aasm')

# Tweak restful_authentication settings: remember me yes/no, link_to_login_with_IP, move include AuthenticatedSystem to user.rb, add map.activate to routes, add password_reset_code migration,
# tweaks to user_mailer.rb & user_observer.rb
if yes?("Allow 'remember me' for cookies?")
  run "perl -i -pe 's/<!-- Uncomment this if you want this functionality//' app/views/sessions/new.html.erb"
  run "perl -i -pe 's/-->//' app/views/sessions/new.html.erb"
end
run "perl -i -pe 's/\\<div id=\"user-bar-greeting\"\\>\\<\\%= link_to_login_with_IP .Not logged in., :style => .border: none;. \\%\\>\\<\\/div\\>//' app/views/users/_user_bar.html.erb"
run "perl -i -pe 's/(ApplicationController < ActionController::Base)/$1\n  include AuthenticatedSystem\n/' app/controllers/application_controller.rb"
run "perl -i -pe 's/include AuthenticatedSystem//' app/controllers/users_controller.rb"
run "perl -i -pe 's/include AuthenticatedSystem//' app/controllers/sessions_controller.rb"
run "perl -i -pe 's/(include Authorization::AasmRoles)/$1\n  include AuthorizationAddOns::Forgot/' app/models/user.rb"
route "map.activate '/activate/:activation_code', :controller => 'users', :action => 'activate', :activation_code => nil"
file "db/migrate/#{Time.now.utc.strftime('%Y%m%d%H%M%S').to_i + 10}_add_password_reset_code_to_users_table.rb", <<-CODE
class AddPasswordResetCodeToUsersTable < ActiveRecord::Migration
  def self.up
    add_column :users, :password_reset_code, :string, :limit => 40
  end
  def self.down
    remove_column :users, :password_reset_code
  end
end
CODE
file "app/controllers/roles_controller.rb", <<-CODE
class RolesController < ApplicationController
  layout 'application'
  #before_filter :check_administrator_role
 
  def index
    @user = User.find(params[:user_id])
    @all_roles = Role.find(:all)
  end
 
  def update
    @user = User.find(params[:user_id])
    @role = Role.find(params[:id])
    unless @user.has_role?(@role.rolename)
      @user.roles << @role
    end
    redirect_to :action => 'index'
  end
  
  def destroy
    @user = User.find(params[:user_id])
    @role = Role.find(params[:id])
    if @user.has_role?(@role.rolename)
      @user.roles.delete(@role)
    end
    redirect_to :action => 'index'
  end
end
CODE

file "db/migrate/#{Time.now.utc.strftime('%Y%m%d%H%M%S').to_i + 15}_create_roles.rb", <<-CODE
class CreateRoles < ActiveRecord::Migration
  def self.up
    create_table :roles, :force => true do |t|
      t.string :rolename
      t.timestamps
    end
  end

  def self.down
    drop_table :roles
  end
end
CODE
file "db/migrate/#{Time.now.utc.strftime('%Y%m%d%H%M%S').to_i + 20}_create_permissions.rb", <<-CODE
class CreatePermissions < ActiveRecord::Migration
  def self.up
    create_table :permissions, :force => true do |t|
       t.integer :role_id, :user_id, :null => false
       t.timestamps
    end
    #Make sure the role migration file was generated first    
    Role.create(:rolename => 'administrator')
    #Then, add default admin user
    #Be sure change the password later or in this migration file
    user = User.new
    user.login = '#{adminlogin}'
    user.email = '#{adminemail.gsub('\@', '@')}'
    user.password = 'password'
    user.password_confirmation = 'password'
    user.state = 'pending'
    user.save(false)
    user.send(:activate!)
    role = Role.find_by_rolename('administrator')
    user = User.find_by_login('#{adminlogin}')
    permission = Permission.new
    permission.role = role
    permission.user = user
    permission.save(false)
  end

  def self.down
    drop_table :permissions
    Role.find_by_rolename('administrator').destroy   
    User.find_by_login('#{adminlogin}').destroy   
  end
end
CODE

file 'app/models/user_mailer.rb', <<-CODE
class UserMailer < ActionMailer::Base
  def signup_notification(user)
    setup_email(user)
    @subject    += 'Please activate your new account'
    @body[:url]  = "http://\#{DOMAIN_URL}/activate/\#{user.activation_code}"
  end
  def activation(user)
    setup_email(user)
    @subject    += 'Your account has been activated!'
    @body[:url]  = "http://\#{DOMAIN_URL}/"
  end
  def forgot_password(user)
    setup_email(user)
    @subject    += 'You have requested to reset your password'
    @body[:url]  = "http://\#{DOMAIN_URL}/reset_password/\#{user.password_reset_code}"
  end  
  def reset_password(user)
    setup_email(user)
    @subject    += 'Your password has been reset'
  end
  protected
    def setup_email(user)
      @recipients  = "\#{user.email}"
      @from        = "\#{ADMIN_EMAIL}"
      @subject     = "[\#{DOMAIN_URL}] "
      @sent_on     = Time.now
      @body[:user] = user
    end
end
CODE
file 'app/models/user_observer.rb', <<-CODE
class UserObserver < ActiveRecord::Observer
  def after_create(user)
    UserMailer.deliver_signup_notification(user)
  end
  def after_save(user)
    UserMailer.deliver_activation(user) if user.recently_activated?
    UserMailer.deliver_forgot_password(user) if user.recently_forgot_password?
    UserMailer.deliver_reset_password(user) if user.recently_reset_password?
  end
end
CODE
file 'app/models/role.rb', <<-CODE
class Role < ActiveRecord::Base
  has_many :permissions
  has_many :users, :through => :permissions
end
CODE
file 'app/models/permission.rb', <<-CODE
class Permission < ActiveRecord::Base
  belongs_to :user
  belongs_to :role
end
CODE


# Domain & Email settings
run "perl -i -pe 's/(\\|config\\|)/$1\n  DOMAIN_URL = \"#{domainurl}\"\n  EMAIL_SERVER = \"#{emailserver}\"\n  ADMIN_EMAIL = \"#{adminemail}\"\n  config.active_record.observers = :user_observer\n/' config/environment.rb"
file 'config/initializers/mail.rb', <<-CODE
ActionMailer::Base.delivery_method = :smtp
ActionMailer::Base.smtp_settings = {
   :address => EMAIL_SERVER,
   :port => 25,
   :domain => DOMAIN_URL, 
   #:authentication => :login,
   #:user_name => "mail@yourapplication.com"
   #:password => "your_password"
}
CODE

# static pages setup
file 'app/controllers/static_pages_controller.rb', <<-CODE
class StaticPagesController < ApplicationController
  def index
    render :action => "home"
  end

  def show
    render :action => params[:page]
  end

end
CODE
file 'app/views/static_pages/home.html.erb', <<-CODE
<% title "Home" %>
<h1>#{app_name.capitalize} Home</h1>
CODE
file 'app/views/static_pages/about.html.erb', <<-CODE
<% title "About" %>
<h1>About #{app_name.capitalize}</h1>
CODE
file 'app/views/static_pages/contact.html.erb', <<-CODE
<% title "Contact" %>
<h1>Contact #{app_name.capitalize}</h1>
CODE
file 'app/views/static_pages/privacy.html.erb', <<-CODE
<% title "Privacy Policy" %>
<h1>Privacy Policy for #{app_name.capitalize}</h1>
CODE
file 'app/views/static_pages/terms.html.erb', <<-CODE
<% title "Terms of Use" %>
<h1>Terms of Use for #{app_name.capitalize}</h1>
CODE
file 'app/views/static_pages/_static_links_bar.html.erb', <<-CODE
<%= link_to 'home', static_pages_path('home') %> |
<%= link_to 'about', static_pages_path('about') %> |
<%= link_to 'contact', static_pages_path('contact') %> |
<%= link_to 'privacy', static_pages_path('privacy') %> |
<%= link_to 'terms', static_pages_path('terms') %>
CODE
file 'app/views/layouts/application.html.erb', <<-CODE
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
  <meta http-equiv="content-type" content="text/html;charset=UTF-8" />
  <title>#{app_name.capitalize}: <%= yield(:title) || "" %></title>
  <%= stylesheet_link_tag '#{app_name}' %>  
  <%= javascript_include_tag :defaults %>
</head>
<body>
<p style="color: green"><%= flash[:notice] %></p>
<%= render :partial => 'users/user_bar' %>
<div style="clear:left"></div>
<%= yield %>
<%= render :partial => 'static_pages/static_links_bar' %>
</body>
</html>
CODE
file "app/helpers/application_helper.rb", <<-CODE
module ApplicationHelper
  def title(page_title)
    content_for(:title) { page_title }
  end
end
CODE
file "public/stylesheets/#{app_name}.css", <<-CODE
div#user-bar-greeting, div#user-bar-action {
float:left;
margin:0 5px 0 0;
}
CODE
route "map.root :controller => 'static_pages'"
route "map.static_pages ':page', :controller => 'static_pages', :action => 'show', :page => /home|about|contact|privacy|terms/"

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

# Exception Notification
if yes?('Include email-based Exception Notifier?')
  plugin 'exception_notifier', :git => 'git://github.com/rails/exception_notification.git'
end

# JQuery
if yes?('Install JQuery?')
  run 'curl -L http://jqueryjs.googlecode.com/files/jquery-1.3.2.min.js > public/javascripts/jquery.js'
end

if yes?('Install X_Send_File?')
  plugin 'x_send_file', :svn => 'http://john.guen.in/svn/plugins/x_send_file'
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

run 'rake db:create:all'
run 'rake db:migrate'