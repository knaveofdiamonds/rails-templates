APP_NAME = @root.split('/').last
# Is rails app part of a larger, pre-gitified project or not?
# For some reason git status returns 256 instead of 0 when successful on my system
SUBPROJECT      = system("git status > /dev/null 2> /dev/null") || $? == 256
INSTALL_GEMS    = yes?("Install gems?")
INSTALL_PLUGINS = yes?("Install plugins?")
USE_OID         = yes?("Use open id?")
address = ask("What is the production server address?").strip
DEPLOY_TO = address.present?() ? address : "192.168.0.10"

git :init unless SUBPROJECT

# Git ignore files
file "log/.gitignore", <<-FILE
*.log
*.pid
FILE

file "tmp/.gitignore", <<-FILE
**/*
FILE

git :add => "."
git :commit => "-m 'Initial rails skeleton commit'"

run "rm public/javascripts/*.js"
run "cp /usr/local/share/jquery/jquery-1.3.2.js public/javascripts/jquery-1.3.2.js"
git :commit => "-am 'Replacing prototype/scriptaculous with jquery'"

# Environment files

file "config/environment.rb", <<-FILE
RAILS_GEM_VERSION = '#{Rails::VERSION::STRING}' unless defined? RAILS_GEM_VERSION
require File.join(File.dirname(__FILE__), 'boot')

Rails::Initializer.run do |config|
  config.frameworks -= [ :active_resource ]
  config.active_record.timestamped_migrations = false
  config.time_zone = 'UTC'
  # config.active_record.observers = :some_observer
end
FILE

# Gems
gem "configatron"
gem "date-performance", :lib => "date/performance"
gem "mislav-will_paginate", :lib => "will_paginate", :source => "http://gems.github.com"
gem "justinfrench-formtastic", :lib => "formtastic", :source => "http://gems.github.com"
gem "knave_extras", :lib => "knave_extras", :source => "http://gems.github.com"
gem "rack_hoptoad"

gem "less", :lib => false, :env => :development
gem "sickill-rack-lesscss", :lib => "rack-lesscss", :env => :development


if USE_OID
  gem "authlogic-oid", :lib => "authlogic_openid"
  gem "ruby-openid", :lib => "openid"
end
gem "authlogic"

# Testing tools
gem :faker, :env => "test"
gem :machinist, :env => "test"
gem :fakeweb, :env => "test"
gem :mocha, :env => "test"
gem :webrat, :env => "test"
gem :cucumber, :env => "test"

if INSTALL_GEMS
  rake "gems:install", :sudo => true
end

environment "config.cache_store = :mem_cache_store", :env => :production
environment "config.middleware.use 'Rack::HoptoadNotifier', 'YOUR HOPTOAD KEY'", :env => :production
environment "config.middleware.use 'Rack::LessCSS', :less_path => File.join(APP_ROOT, 'public', 'css')", :env => :development

if INSTALL_PLUGINS
  # Plugins
  plugin :rails_sql_views, 
    :git => "git://github.com/aeden/rails_sql_views.git", :submodule => true
  plugin :no_peeping_toms, 
    :git => "git://github.com/pat-maddox/no-peeping-toms.git", :submodule => true
  plugin :jrails, 
    :git => "git://github.com/aaronchi/jrails.git", :submodule => true
  plugin :validation_reflection, 
    :git => "git://github.com/redinger/validation_reflection.git", :submodule => true

  if USE_OID
    plugin :open_id_authentication, 
      :git => "git://github.com/rails/open_id_authentication.git", :submodule => true
  end
end

# Clear out some irrelevant files
run "rm public/index.html"
run "rm README"
run "rm public/favicon.ico"
run "rm public/images/rails.png"

# Database.yml
file "config/database.yml", <<-FILE
development: &default_settings 
  adapter: mysql
  encoding: utf8
  reconnect: true
  pool: 5
  socket: /var/run/mysqld/mysqld.sock
  database: #{APP_NAME}_development
  username: root
  password:

test:
  <<: *default_settings
  database: #{APP_NAME}_test

production:
  <<: *default_settings
  database: #{APP_NAME}
  username: #{APP_NAME}
  password:
FILE

rake "db:create"
rake "db:create", :env => 'test'

# Deployment configuration
file "config/deploy.rb", <<-FILE
set :application, "#{APP_NAME}"
\#set :domain, "10.37.129.3"
set :domain, "#{DEPLOY_TO}"
set :deploy_to, "/usr/local/share/sites/\#{application}"
set :scm_path, "\#{deploy_to}/\#{application}.git"
set :revision, "HEAD"
set :remote_name, "production"
FILE

rakefile("vlad.rake") do
<<-FILE
begin
  require 'vlad'
  require 'vlad/core'
  require 'vlad/passenger'
  require 'knave_extras/tasks/vlad'

  Kernel.load 'config/deploy.rb'
rescue LoadError
  # Do nothing
end
FILE
end

file "test/blueprints.rb", "# Add your model blueprints to this file\n"

generate :cucumber
generate :session, "UserSession"
generate :controller, "UserSessions new create destroy"
rake "open_id_authentication:db:create"
route "map.resources :user_sessions"

user_options = ["User", "name:string", "username:string", "email:string", "--skip-migration"]
user_options << "openid_identifier:string" if USE_OID
generate :scaffold, user_options.join(" ")

file "app/models/user.rb", <<-FILE
class User < ActiveRecord::Base
  acts_as_authentic
end
FILE

file "db/migrate/002_create_users.rb", <<-FILE
class CreateUsers < ActiveRecord::Migration
  def self.up
    create_table :users do |t|
      t.timestamps
    end
  end

  def self.down
    drop_table :users
  end
end
FILE

file "app/controllers/application_controller.rb", <<-FILE
# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  helper :all
  helper_method :current_user_session, :current_user
  filter_parameter_logging :password, :password_confirmation
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  protected

  def current_user_session
    return @current_user_session if defined?(@current_user_session)
    @current_user_session = UserSession.find
  end
    
  def current_user
    return @current_user if defined?(@current_user)
    @current_user = current_user_session && current_user_session.record
  end
    
  def store_location
    session[:return_to] = request.request_uri
  end
    
  def redirect_back_or_default(default)
    redirect_to(session[:return_to] || default)
    session[:return_to] = nil
  end
end
FILE

file "app/controllers/user_sessions_controller.rb", <<-FILE
class UserSessionsController < ApplicationController
  def new
    @user_session = UserSession.new
  end
  
  def create
    @user_session = UserSession.new(params[:user_session])
    @user_session.save do |result|
      if result
        flash[:notice] = "Welcome back."
        redirect_back_or_default account_url
      else
        render :action => :new
      end
    end
  end
  
  def destroy
    current_user_session.destroy
    flash[:notice] = "Logged out successfully."
    redirect_back_or_default new_user_session_url
  end
end
FILE

rake "db:migrate"
rake "db:test:clone"

git :add => "."
git :commit => "-a -m 'Additions from boots rails template'"
