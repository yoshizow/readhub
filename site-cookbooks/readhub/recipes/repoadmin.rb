#
# Cookbook Name:: readhub
# Recipe:: repoadmin
#
# Copyright 2013, Yoshitaro Makise
# 

include_recipe 'ruby_build'
include_recipe 'rbenv::system'

rbenv_gem 'thin' do
  action :install
end

cookbook_file '/etc/init.d/readhub-repoadmin' do
  mode 0755
  owner 'root'
  group 'root'
end

directory '/etc/thin' do
  mode 0755
  owner 'root'
  group 'root'
end

cookbook_file '/etc/thin/readhub-repoadmin.yml' do
  mode 0644
  owner 'root'
  group 'root'
end

directory '/var/run/thin' do
  mode 0755
  owner 'www-data'
  group 'www-data'
end

execute 'bundle install' do
  command 'bundle install --deployment --binstubs=vendor/bin'
  cwd '/vagrant'
  environment ({'HOME' => '/vagrant'})
end

service 'readhub-repoadmin' do
  supports :start => true, :stop => true, :restart => true
  action [:enable, :start]
end
