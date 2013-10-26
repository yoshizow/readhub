#
# Cookbook Name:: readhub
# Recipe:: indexer
#
# Copyright 2013, Yoshitaro Makise
# 

include_recipe 'global'

READHUB_HOME = node['readhub']['readhub_home']
READHUB_SRC = node['readhub']['readhub_src']

directory "#{READHUB_HOME}" do
  mode 0755
  owner 'www-data'
  group 'www-data'
end

directory "#{READHUB_HOME}/indices" do
  mode 0755
  owner 'www-data'
  group 'www-data'
end

execute 'install checkout-and-index' do
  command 'make install'
  cwd "#{READHUB_SRC}/indexer"
end

group 'git' do
  action :modify
  members 'www-data'
  append true
end
