#
# Cookbook Name:: site-gitolite
# Recipe:: default
#
# Copyright 2012, TNW-labs
# Copyright 2013, Yoshitaro Makise
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# 

HOME='/var/git'

include_recipe 'gitolite2'
include_recipe 'ssh_known_hosts'

ssh_known_hosts_entry 'localhost'

execute "git clone git@localhost:gitolite-admin" do
  creates "#{HOME}/gitolite-admin"
  user "git"
  group "git"
  cwd "#{HOME}"
  environment "HOME" => HOME
end

execute "git pull" do
  user "git"
  group "git"
  cwd "#{HOME}/gitolite-admin"
  environment "HOME" => HOME
end

template "#{HOME}/gitolite-admin/conf/gitolite.conf" do
  owner "git"
  group "git"
end

template "#{HOME}/gitolite/src/VREF/readhub-update-hook" do
  owner "git"
  group "git"
  mode 0755
end

bash "reconfigure gitolite" do
  code <<-EOF
     set -e -x
     git add keydir/*.pub conf/gitolite.conf
     git commit -m 'reconfigure'
     git push
  EOF
  cwd "#{HOME}/gitolite-admin/"
  user "git"
  group "git"
  environment "HOME" => HOME
  not_if "git status |grep -q '^nothing to commit'", :user => "git", :group => "git", :cwd => "#{HOME}/gitolite-admin/"
end
