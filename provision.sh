#!/bin/bash

# Simple setup file to take a fresh Ubuntu 8.04 box and turn it into a shiny
# ruby serving machine.

# Make sure we're up to date
aptitude -y update
aptitude -y dist-upgrade

# ensure we don't ge prompted for mysql root password
echo mysql-server-5.0 mysql-server/root_password password qwerty > tmp_mysql_install_settings.txt
echo mysql-server-5.0 mysql-server/root_password_again password qwerty >> tmp_mysql_install_settings.txt
debconf-set-selections < tmp_mysql_install_settings.txt
rm tmp_mysql_install_settings.txt

# Install packages
aptitude -y install emacs22 git-core ruby ruby1.8-dev irb mysql-client mysql-server wget build-essential libmysqlclient15-dev libxml2-dev autoconf libreadline-ruby libopenssl-ruby rsync libxslt1-dev

# Get and install rubygems
chgrp admin /usr/local/src
cd /usr/local/src
wget http://rubyforge.org/frs/download.php/57643/rubygems-1.3.4.tgz
tar -xzf rubygems-1.3.4.tgz
cd rubygems-1.3.4
ruby setup.rb --no-rdoc --no-ri
ln -s /usr/bin/gem1.8 /usr/bin/gem

gem sources --add http://gems.github.com/

# Install gems
gem install mysql rails rake passenger --no-rdoc --no-ri

# Install nginx/passenger
passenger-install-nginx-module --auto --auto-download --prefix=/usr/local/nginx

cd /usr/local/nginx
rm -rf conf html
git clone git://github.com/knaveofdiamonds/nginx-conf.git conf

cd /usr/local/share
mkdir sites
chgrp admin sites
chmod 775 sites
chmod +s sites

# TODO write out nginx init.d file

echo "Installation complete."
echo "Remember to change the mysql root password from 'qwerty'."
