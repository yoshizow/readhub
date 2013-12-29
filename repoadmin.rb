# -*- coding: utf-8 -*-

require 'sinatra'
require 'sinatra/json'
require 'gitolite'
require 'dotenv'

require_relative './model.rb'

# configurations ----------

$stdout.sync = true

Dotenv.load('/etc/readhub.env')

configure do
  enable :logging
end

configure :development do
  require 'sinatra/reloader'
  use Rack::CommonLogger
end

# models ----------

DEFAULT_PROVIDER = 'github'

# APIs ----------

# API: register repository
get '/repos/:user/:project/:revision/new' do |user_name, proj_name, commit_id|
  user = DB::User.first(:name => user_name, :provider => DEFAULT_PROVIDER)
  halt 404  if user == nil
  now = Time.now
  project = user.projects.first(:name => proj_name)
  if project == nil
    project = user.projects.new(:name => proj_name, :modified_at => now)
  end
  # 結構面倒
  revision = project.revisions.first(:commit_id => commit_id)
  if revision != nil
    revision.update(:modified_at => now)
  else
    revision = project.revisions.new(:commit_id => commit_id, :modified_at => now)
  end
  user.save

  json 'status' => 'OK'
end

# API: register public key
post '/certs/:user/new' do |user_name|
  user = DB::User.first(:name => user_name, :provider => DEFAULT_PROVIDER)
  halt 404  if user == nil

  ga_repo = Gitolite::GitoliteAdmin.new("#{ENV['READHUB_HOME']}/gitolite-admin")
  key_content = request.body.read
  key = Gitolite::SSHKey.from_string(key_content, user_name)
  ga_repo.add_key(key)
  ga_repo.save_and_apply

  json 'status' => 'OK'
end

# API: unregister public key
# note: this is post method as it requires key content
post '/certs/:user/delete' do |user_name|
  user = DB::User.first(:name => user_name, :provider => DEFAULT_PROVIDER)
  halt 404  if user == nil
  
  ga_repo = Gitolite::GitoliteAdmin.new("#{ENV['READHUB_HOME']}/gitolite-admin")
  key_content = request.body.read
  key = Gitolite::SSHKey.from_string(key_content, user_name)
  ga_repo.rm_key(key)
  ga_repo.save_and_apply

  json 'status' => 'OK'
end
