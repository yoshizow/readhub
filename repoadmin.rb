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
get '/repos/:user/:project/:revision/new' do |user_name, proj_name, revision|
  user = DB::User.first(:name => user_name, :provider => DEFAULT_PROVIDER)
  halt 404  if user == nil
  project = user.projects.first_or_new(:name => proj_name, :revision => revision)
  project.repo = DB::Repo.new(:path => "#{ENV['GITOLITE_HOME']}/repositories/#{user_name}/#{proj_name}.git")
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
  
  ga_repo = Gitolite::GitoliteAdmin.new("#{ENV['READHUB_HOME']/gitolite-admin")
  key_content = request.body.read
  key = Gitolite::SSHKey.from_string(key_content, user_name)
  ga_repo.rm_key(key)
  ga_repo.save_and_apply

  json 'status' => 'OK'
end
