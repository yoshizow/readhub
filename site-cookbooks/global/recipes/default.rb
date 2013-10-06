#
# Cookbook Name:: global
# Recipe:: default
#
# Copyright 2013, Yoshitaro Makise
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe "build-essential"

version = node['global']['version']

package 'libncurses5-dev' do
  action :install
end

remote_file "#{Chef::Config[:file_cache_path]}/global-#{version}.tar.gz" do
  source "#{node['global']['url']}/global-#{version}.tar.gz"
  checksum node['global']['checksum']
  mode 0644
end

bash "install GNU GLOBAL" do
  cwd Chef::Config[:file_cache_path]
  code <<-EOF
    tar xf global-#{version}.tar.gz
    (cd global-#{version} && ./configure #{node['global']['configure_options'].join(" ")})
    (cd global-#{version} && make && make install)
  EOF
  not_if "global --version | grep -F '#{version}'"
end
