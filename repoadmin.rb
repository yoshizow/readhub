# -*- coding: utf-8 -*-

require 'sinatra'
require 'sinatra/json'
require 'gitolite'
require 'dotenv'
require 'fileutils'

require_relative './model.rb'

# configurations ----------

$stdout.sync = true

Dotenv.load('/etc/readhub.env')

configure do
  enable :logging
end

configure :development do
  require 'sinatra/reloader'
  also_reload './*.rb'
  use Rack::CommonLogger
end

# APIs ----------

# API: register repository
get '/repos/:user/:project/:revision/new' do |user_name, proj_name, commit_id|
  user = Model::User.where(name: user_name, provider: DEFAULT_PROVIDER).first
  halt 404  if user == nil
  project = user.projects.where(name: proj_name).first_or_create
  revision = project.revisions.first_or_create(commit_id: commit_id)

  json 'status' => 'OK'
end

# API: register public key
post '/certs/:user/new' do |user_name|
  user = Model::User.where(name: user_name, provider: DEFAULT_PROVIDER).first
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
  user = Model::User.where(name: user_name, provider: DEFAULT_PROVIDER).first
  halt 404  if user == nil
  
  ga_repo = Gitolite::GitoliteAdmin.new("#{ENV['READHUB_HOME']}/gitolite-admin")
  key_content = request.body.read
  key = Gitolite::SSHKey.from_string(key_content, user_name)
  ga_repo.rm_key(key)
  ga_repo.save_and_apply

  json 'status' => 'OK'
end

# API: delete repository
get '/repositories/:user/:project/delete' do |user_name, proj_name|
  user = Model::User.where(name: user_name, provider: DEFAULT_PROVIDER).first
  halt 404  if user == nil
  project = user.projects.where(name: proj_name).first
  halt 404 if project == nil

  # remove index
  FileUtils.rm_rf("#{ENV['READHUB_HOME']}/indices/#{user.name}/#{project.name}")
  # remove repo
  system("HOME=#{ENV['GITOLITE_HOME']} GL_USER=#{user.name} /var/git/bin/gitolite D unlock #{user.name}/#{project.name}")
  system("HOME=#{ENV['GITOLITE_HOME']} GL_USER=#{user.name} /var/git/bin/gitolite D rm #{user.name}/#{project.name}")
  # remove from DB
  project.destroy

  json 'status' => 'OK'
end
