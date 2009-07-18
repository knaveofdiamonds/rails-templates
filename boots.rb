gem :authlogic
gem "ruby-openid", :lib => "openid"
gem "authlogic-oid"
gem "mislav-will_paginate", :lib => "will_paginate", :source => "http://gems.github.com"
plugin :open_id_authentication, :git => "git://github.com/rails/open_id_authentication.git"
plugin :hoptoad_notifier, :git => "git://github.com/thoughtbot/hoptoad_notifier.git"

# Testing tools
gem :faker, :env => "test"
gem :machinist, :env => "test"
gem :fakeweb, :env => "test"
gem :mocha, :env => "test"
gem :webrat, :env => "test"
gem :cucumber, :env => "test"
plugin :no_peeping_toms, :git => "git://github.com/pat-maddox/no-peeping-toms.git"

generate :cucumber

# Clear out some irrelevant files
run "rm public/index.html"
run "rm README"
run "rm public/images/rails.png"
run "rm public/javascripts/*.js"

run "cp config/database.yml config/database.example.yml"

# TODO add config.active_record.timestamped_migrations = false to environment.rb
