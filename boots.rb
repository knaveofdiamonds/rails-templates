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
gem "ruby-openid", :lib => "openid" if USE_OID
gem "less", :lib => false

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
  plugin :less_for_rails, 
    :git => "git://github.com/augustl/less-for-rails.git", :submodule => true

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

file "app/views/layouts/application.html.erb", <<-FILE
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
       "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
  <meta http-equiv="content-type" content="text/html;charset=UTF-8" />
  <title><%= controller.action_name %></title>
  <%= stylesheet_link_tag 'resets' %>
  <%= stylesheet_link_tag 'typography' %>
</head>
<body>

<p style="color: green"><%= flash[:notice] %></p>

<%= yield %>

<% unless Rails.env.development? %>
  <!--
    <script type="text/javascript">
      var gaJsHost = (("https:" == document.location.protocol) ? "https://ssl." : "http://www.");
      document.write(unescape("%3Cscript src='" + gaJsHost + "google-analytics.com/ga.js' type='text/javascript'%3E%3C/script%3E"));
    </script>
    <script type="text/javascript">
      var pageTracker = _gat._getTracker("<%= google_analytics_token %>");
      pageTracker._initData();
      pageTracker._trackPageview();
    </script>
  -->
<% end %>
</body>
</html>
FILE

file "app/helpers/application_helper.rb", <<-FILE
# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  def google_analytics_token
    # Return a string with your google analytics token here.
    ""
  end
end
FILE

generate :styles
generate :cucumber

rake "open_id_authentication:db:create" if USE_OID

rake "db:migrate"
rake "db:test:clone"

git :add => "."
git :commit => "-a -m 'Additions from boots rails template'"
