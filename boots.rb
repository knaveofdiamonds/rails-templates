APP_NAME = @root.split('/').last
# Is rails app part of a larger, pre-gitified project or not?
# For some reason git status returns 256 instead of 0 when successful on my system
SUBPROJECT = system("git status > /dev/null 2> /dev/null") || $? == 256

git :init unless SUBPROJECT

# Git ignore files
file "log/.gitignore", <<-FILE
*.log
*.pid
FILE

file ".gitignore", <<-FILE
config/database.yml
FILE

file "tmp/.gitignore", <<-FILE
**/*
FILE

git :add => "."
git :commit => "-m 'Initial rails skeleton commit'"

# Gems
gem "authlogic-oid", :lib => "authlogic_openid"
gem "ruby-openid", :lib => "openid"
gem "authlogic"
gem "configatron"
gem "date-performance", :lib => "date/performance"
gem "mislav-will_paginate", :lib => "will_paginate", :source => "http://gems.github.com"
gem "justinfrench-formtastic", :lib => "formtastic", :source => "http://gems.github.com"
gem "knave_extras", :lib => "knave_extras", :source => "http://gems.github.com"

# Testing tools
gem :faker, :env => "test"
gem :machinist, :env => "test"
gem :fakeweb, :env => "test"
gem :mocha, :env => "test"
gem :webrat, :env => "test"
gem :cucumber, :env => "test"

if yes?("Install plugins?")
  # Plugins
  plugin :open_id_authentication, 
    :git => "git://github.com/rails/open_id_authentication.git", :submodule => true
  plugin :hoptoad_notifier, 
    :git => "git://github.com/thoughtbot/hoptoad_notifier.git", :submodule => true
  plugin :rails_sql_views, 
    :git => "git://github.com/aeden/rails_sql_views.git", :submodule => true
  plugin :no_peeping_toms, 
    :git => "git://github.com/pat-maddox/no-peeping-toms.git", :submodule => true
# plugin :jrails, 
#  :git => "git://github.com/aaronchi/jrails.git", :submodule => true
  plugin :validation_reflection, 
    :git => "git://github.com/redinger/validation_reflection.git", :submodule => true
end

if yes?("Install gems?")
  rake "gems:install", :sudo => true
end

# Clear out some irrelevant files
run "rm public/index.html"
run "rm README"
run "rm public/favicon.ico"
run "rm public/images/rails.png"
run "rm public/javascripts/*.js"
run "rm config/database.yml"
run "cp /usr/local/share/jquery/jquery-1.3.2.js public/javascripts/jquery-1.3.2.js"

# Database.yml
file "config/database.yml.example", <<-FILE
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
run "cp config/database.yml.example config/database.yml"

# Deployment configuration
file "config/deploy.rb", <<-FILE
set :application, "#{APP_NAME}"
set :domain, "10.37.129.3"
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


environment "config.active_record.timestamped_migrations = false"

generate :cucumber
generate :session, "UserSession"

rake "db:create"
rake "db:create", :env => 'test'

git :add => "."
git :commit => "-a -m 'Additions from boots rails template'"
