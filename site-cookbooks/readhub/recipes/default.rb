#
# Cookbook Name:: readhub
# Recipe:: default
#
# Copyright 2013, Yoshitaro Makise
# 

include_recipe 'readhub::gitolite'
include_recipe 'readhub::web'
include_recipe 'readhub::repoadmin'
include_recipe 'readhub::indexer'
