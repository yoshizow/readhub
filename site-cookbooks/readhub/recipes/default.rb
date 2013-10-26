#
# Cookbook Name:: readhub
# Recipe:: default
#
# Copyright 2013, Yoshitaro Makise
# 

template '/etc/readhub.env' do
  mode 0644
  owner 'root'
  group 'root'
  variables(:readhub_home => node['readhub']['readhub_home'],
            :readhub_src  => node['readhub']['readhub_src'], 
            :gitolite_home => node['readhub']['gitolite_home'])
end

include_recipe 'readhub::gitolite'
include_recipe 'readhub::web'
include_recipe 'readhub::repoadmin'
include_recipe 'readhub::indexer'
