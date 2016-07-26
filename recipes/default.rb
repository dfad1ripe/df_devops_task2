#
# Cookbook Name:: Task2b
# Recipe:: default
#
# Copyright (C) 2016 YOUR_NAME
#
# All rights reserved - Do Not Redistribute
#

#
# Install MySQL and start the service
#

package 'mysql' do
  action :install
end

package 'mysql-server' do
  action :install
end

service 'mysqld' do
  action [:enable, :start]
end

#
# Exec mysql_secure_installation
# This deletes obvious DB and users, disables remote login.
# It could also set root password, but we'll do that later,
# because the task is to keep that password in a data_bag.
#

template '/home/vagrant/secure_install' do
  source 'secure_install.erb'
  mode '0600'
end

execute 'secure_install' do
  command 'cat /home/vagrant/secure_install |' \
  ' /usr/bin/mysql_secure_installation'
  only_if 'mysql -e "show databases" | grep test'
end

# Here I should delete the file, but this violates the subtask
# "Try to achieve state when your consequent chef-client runs results
# in 0 resources updates".
# file '/home/vagrant/secure_install' do
#  action :delete
# end

#
# Setup the root password
#

db_admins = data_bag('db_admins')
db_admins.each do |dba|
  db_admin = data_bag_item('db_admins', dba)
  admin_id = db_admin['id']
  next if admin_id != 'root'
  root_pwd = db_admin['password']
  node.default['root_pwd'] = root_pwd
  execute 'set_root_password' do
    command "mysqladmin -u root password #{root_pwd}"
    only_if 'mysql -e "select 1"'
  end
end

#
# Create MySQL users
# (via data_bags)
#

db_users = data_bag('db_users')
db_users.each do |dbu|
  root_pwd = node['root_pwd']
  db_user = data_bag_item('db_users', dbu)
  db_username = db_user['username']
  db_full_username = "'#{db_username}'@'localhost'"
  mysql_arg = "create user #{db_full_username} identified by '#{db_username}'"
  execute "mysql_useradd #{db_username}" do
    command "mysql -p#{root_pwd} -e \"#{mysql_arg}\""
    not_if "mysql -p#{root_pwd} -e \"select user from mysql.user\" |\
    grep #{db_username}"
  end
end

#
# Create databases
#

db_dbs = data_bag('db_dbs')
db_dbs.each do |dbi|
  root_pwd = node['root_pwd']
  db = data_bag_item('db_dbs', dbi)
  db_name = db['dbname']
  mysql_arg = "create database #{db_name}"
  execute "mysql_dbadd #{db_name}" do
    command "mysql -p#{root_pwd} -e \"#{mysql_arg}\""
    not_if "mysql -p#{root_pwd} -e \"show databases\" | grep #{db_name}"
  end
end

#
# Here, I should grant / flush privileges,
# but this was not specified in the task.
# Anyway, need logical link between users and databases.
# One of options: single json bag for both, this would work in this
# particular case.
#
