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

# Allow 'www-data' user write /vagrant/db/schema.rb
# TODO: do this only in development mode
# --------------------------------------
directory "#{node['readhub']['readhub_src']}/db" do
  # Make db folder World-writable.
  # Adding 'www-data' user to 'vagrant' group and chmod 0775 db does not
  # work. Chef's setgid function seems ignore secondary groups.
  mode 0777
end
# --------------------------------------

include_recipe 'readhub::gitolite'
include_recipe 'readhub::web'
include_recipe 'readhub::repoadmin'
include_recipe 'readhub::indexer'
