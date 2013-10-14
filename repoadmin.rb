# -*- coding: utf-8 -*-

require 'sinatra'

require_relative './model.rb'

# configurations ----------

$stdout.sync = true

configure do
  enable :logging
end

configure :development do
  require 'sinatra/reloader'
  use Rack::CommonLogger
end

# models ----------

# APIs ----------

# API: register repository
get '/repos/:user/:project/:revision/new' do |user_name, proj_name, revision|
  user = DB::User.first(:provider => 'github', :name => user_name)
  halt 404  if user == nil
  project = user.projects.first_or_new(:name => proj_name, :revision => revision)
  project.repo = DB::Repo.new(:path => "/var/git/repositories/#{user_name}/#{proj_name}.git")
  user.save
end
