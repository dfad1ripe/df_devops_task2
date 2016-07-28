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

%w(mysql mysql-server expect).each do |pkg|
  package pkg do
    action :install
  end
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

sec_inst_script = "#{Chef::Config['file_cache_path']}/secure_install.sh"
cookbook_file sec_inst_script do
  source 'secure_install.sh'
  mode '0711'
  only_if 'mysql -e "show databases" | grep test'
end

execute 'secure_install' do
  command sec_inst_script
  only_if 'mysql -e "show databases" | grep test'
end

file sec_inst_script do
  action :delete
  only_if { File.exist?(sec_inst_script) }
end

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

#
# Now, some games with schema in cookbook_file
#

devops_sql = "#{Chef::Config['file_cache_path']}/devops.sql"

cookbook_file devops_sql do
  root_pwd = node['root_pwd']
  action :create
  source 'devops.sql'
  not_if "mysql -p#{root_pwd} -e \"show databases\" | grep devops"
end

execute 'create_db_from_file' do
  root_pwd = node['root_pwd']
  command "mysql -p#{root_pwd} < #{devops_sql}"
  not_if "mysql -p#{root_pwd} -e \"show databases\" | grep devops"
end

file devops_sql do
  action :delete
  only_if { File.exist?(devops_sql) }
end
