#
# Cookbook Name:: readhub
# Recipe:: indexer
#
# Copyright 2013, Yoshitaro Makise
# 

include_recipe 'global'

directory '/var/readhub' do
  mode 0755
  owner 'www-data'
  group 'www-data'
end

directory '/var/readhub/indices' do
  mode 0755
  owner 'www-data'
  group 'www-data'
end

execute 'install checkout-and-index' do
  command 'make install'
  cwd '/vagrant/indexer'
end

group 'git' do
  action :modify
  members 'www-data'
  append true
end
