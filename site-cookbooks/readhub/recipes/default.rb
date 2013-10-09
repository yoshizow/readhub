#
# Cookbook Name:: readhub
# Recipe:: default
#
# Copyright 2013, Yoshitaro Makise
# 

include_recipe 'ruby_build'
include_recipe 'rbenv::system'

include_recipe 'readhub::indexer'

rbenv_gem 'thin' do
  action :install
end

cookbook_file '/etc/init.d/readhub-web' do
  mode 0755
  owner 'root'
  group 'root'
end

directory '/etc/thin' do
  mode 0755
  owner 'root'
  group 'root'
end

cookbook_file '/etc/thin/readhub-web.yml' do
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

service 'readhub-web' do
  supports :start => true, :stop => true, :restart => true
  action [:enable, :start]
end
