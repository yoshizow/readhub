# -*- coding: utf-8 -*-
#
# Cookbook Name:: readhub
# Recipe:: gitolite
#
# Copyright 2013, Yoshitaro Makise
# 

ADMIN_HOME = node['readhub']['readhub_home']
ADMIN_SRC  = node['readhub']['readhub_src']
ADMIN_SSH_HOME = '/var/www'    # www-data's real home directory where .ssh/ will be stored
# TODO: make dedicated user for repoadmin, whose home directory is ADMIN_HOME

directory "#{ADMIN_HOME}" do
  mode 0755
  owner 'www-data'
  group 'www-data'
end

directory "#{ADMIN_SSH_HOME}" do
  mode 0755
  owner 'www-data'
  group 'www-data'
end

directory "#{ADMIN_SSH_HOME}/.ssh" do
  mode 0700
  owner 'www-data'
  group 'www-data'
end

#
# Prepare key pair for gitolite admin
#

execute "ssh-keygen -t rsa -f #{ADMIN_SSH_HOME}/.ssh/id_rsa -N '' -C gitolite" do
  creates "#{ADMIN_SSH_HOME}/.ssh/id_rsa"
  user 'www-data'
  group 'www-data'
  cwd ADMIN_HOME
  environment "HOME" => ADMIN_HOME
end

node.override['gitolite2']['public_key_path'] = "#{ADMIN_SSH_HOME}/.ssh/id_rsa.pub"
node.override['gitolite2']['local_code'] = "#{ADMIN_SRC}/gitolite/local"

#
# Setup gitolite
#

include_recipe 'gitolite2'

#
# Configure gitolite
#

include_recipe 'ssh_known_hosts'

ssh_known_hosts_entry 'localhost'

execute "git clone git@localhost:gitolite-admin" do
  creates "#{ADMIN_HOME}/gitolite-admin"
  user "www-data"
  group "www-data"
  cwd "#{ADMIN_HOME}"
  environment "HOME" => ADMIN_SSH_HOME
end

execute "git pull" do
  user "www-data"
  group "www-data"
  cwd "#{ADMIN_HOME}/gitolite-admin"
  environment "HOME" => ADMIN_HOME
end

template "#{ADMIN_HOME}/gitolite-admin/conf/gitolite.conf" do
  owner "www-data"
  group "www-data"
  mode 0644
end

bash "reconfigure gitolite" do
  code <<-EOF
     set -e -x
     git add keydir/*.pub conf/gitolite.conf
     git commit -m 'reconfigure'
     git push
  EOF
  cwd "#{ADMIN_HOME}/gitolite-admin/"
  user "www-data"
  group "www-data"
  environment "HOME" => ADMIN_HOME
  not_if "git status |grep -q '^nothing to commit'", :user => "git", :group => "git", :cwd => "#{ADMIN_HOME}/gitolite-admin/"
end
