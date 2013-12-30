# -*- coding: utf-8 -*-

require 'sinatra'
require 'sinatra/json'
require 'sinatra/flash'
require 'rugged'
require 'liquid'
require 'json'
require 'rest_client'
require 'pp'
require 'dotenv'
#require 'test/unit'

require_relative './model.rb'

#include Test::Unit::Assertions

APPLICATION_NAME = 'ReadHub'

# configurations ----------

$stdout.sync = true

Dotenv.load('/etc/readhub.env')

configure do
  enable :sessions
  enable :logging
end

configure :development do
  require 'sinatra/reloader'
  use Rack::CommonLogger
end

# handle views/*.liquid.html as Liquid templates
Tilt.prefer Tilt::LiquidTemplate, '.liquid.html'

REPOADMIN_SERVER_URL = 'http://localhost:4000'

# helper routines ----------

def url_for_path(revision, path)
  return "/#{revision.project.user.name}/#{revision.project.name}/code/#{revision.commit_id}/#{path}".gsub(%r!//+!, '/')
end

def linkify(html, url)
  return '<a href="' + url + '">' + html + '</a>'
end

def make_path_breadcrumb_html(revision, path)
  def render_html(list)
    if list.empty?
      return ''
    else
      return '<span class="path_breadcrumb">' +
             (list.each_with_index.collect do |e, i|
                if i < list.size - 1
                  linkify(Rack::Utils.escape_html(e[0]), e[1])
                else
                  Rack::Utils.escape_html(e[0])
                end
              end.join('/')) +
              '</span>'
    end
  end

  def make_list(revision, path)
    path_components = path.split('/')
    #assert !path_components.include?('')
    list = path_components.each_with_index.collect do |name, idx|
             [name,
              url_for_path(revision, path_components[0..idx].join('/'))]
           end
    return list
  end

  return render_html(make_list(revision, path))
end

def make_project_link_html(revision)
  return linkify(Rack::Utils.escape_html("#{revision.project.name}-#{revision.commit_id}"), url_for_path(revision, '/'))
end

def bootstrap_flash
  flash.map do |type, message|
    cls = { notice: 'alert-success',
            error: 'alert-danger' }[type]
    "<div class='alert #{cls} fade in'>#{Rack::Utils.escape_html(message)}
     <a class='close' data-dismiss='alert' href='#' aria-hidden='true'>&times;</a></div>"
  end.join
end

# APIs ----------

# Remove trailing slash for every request paths
before { request.path_info.sub! %r{/$}, '' }

# API: get comments for specified file
get '/:user/:project/:revision/files/*/comments' do |user_name, proj_name, commit_id, path|
  revision = Model::Revision.lookup(user_name, proj_name, commit_id)
  halt 404  if revision == nil

  blob = GitObj.create(revision, path)
  halt 404  if blob == nil
  halt 404  if blob.is_tree?
  
  comments = revision.get_comments(path)

  json comments.map { |e| { :line => e.line, :text => e.text } }
end

# API: add new comment
post '/:user/:project/:revision/files/*/comments/new' do |user_name, proj_name, commit_id, path|
  halt 404  if !session[:logged_in_user]
  logged_in_user = Model::User.where(name: session[:logged_in_user], provider: DEFAULT_PROVIDER).first
  halt 404 if logged_in_user == nil

  revision = Model::Revision.lookup(user_name, proj_name, commit_id)
  halt 404  if revision == nil

  params = JSON.parse(request.body.read)
  line = params['line']
  text = params['text']

  revision.add_comment(logged_in_user, path, line, text)

  json 'status' => 'OK'
end

# API: remove comment
delete '/:user/:project/:revision/files/*/comments/:line' do |user_name, proj_name, commit_id, path, line|
  halt 404  if !session[:logged_in_user]
  logged_in_user = Model::User.where(name: session[:logged_in_user], provider: DEFAULT_PROVIDER).first
  halt 404 if logged_in_user == nil

  revision = Model::Revision.lookup(user_name, proj_name, commit_id)
  halt 404  if revision == nil

  revision.delete_comment(logged_in_user, path, line)

  json 'status' => 'OK'
end

# views ----------

# view: root index
get '/' do
  locals = { :title => "Projects - #{APPLICATION_NAME}",
             :list => Model::User.all.collect do |e|
               { 'url'  => "/#{e.name}",
                 'name' => "#{e.name}" }
             end,
             :logged_in_user => session[:logged_in_user]
           }
  liquid :project_index, :locals => locals
end

get '/login' do
  liquid :login, :locals => { :title => "Login - #{APPLICATION_NAME}" }
end

post '/session' do
  username = request.params['username']
  halt 404 if !username || username.empty?
  session[:logged_in_user] = username
  db_user = Model::User.where(name: username, provider: DEFAULT_PROVIDER).first_or_create
  db_user.save!
  puts "Logged in as #{username}"
  redirect to('/')
end

get '/logout' do
  puts "Logged out from #{session[:logged_in_user]}"
  session.delete(:logged_in_user)
  redirect to('/')
end

get '/settings/ssh' do
  halt 404  if !session[:logged_in_user]
  db_user = Model::User.where(name: session[:logged_in_user], provider: DEFAULT_PROVIDER).first
  halt 404 if db_user == nil

  db_public_key = db_user.public_keys.first
  if db_public_key != nil
    key = db_public_key.public_key
  else
    key = ""
  end

  locals = { :title => "SSH Keys - #{APPLICATION_NAME}",
             :flash_messages => bootstrap_flash,
             :logged_in_user => db_user.name,
             :key => key
           }
  liquid :settings_ssh, :locals => locals
end

post '/account/public_keys' do
  key = request.params['key']
  halt 404 if !key
  halt 404  if !session[:logged_in_user]
  db_user = Model::User.where(name: session[:logged_in_user], provider: DEFAULT_PROVIDER).first
  halt 404 if db_user == nil
  
  key = key.strip
  if key.empty?
    db_public_key = db_user.public_keys.first
    if db_public_key != nil
      db_public_key.destroy
      RestClient.post "#{REPOADMIN_SERVER_URL}/certs/#{db_user.name}/delete", key, :content_type => "application/octet-stream"
    end
  else
    db_public_key = db_user.public_keys.first
    if db_public_key != nil
      db_public_key.update(public_key: key)
    else
      db_user.public_keys.create(public_key: key)
    end
    RestClient.post "#{REPOADMIN_SERVER_URL}/certs/#{db_user.name}/new", key, :content_type => "application/octet-stream"
  end

  flash[:notice] = "Saved."
  redirect to('/settings/ssh')
end

# view: repository index
get '/:user' do |user_name|
  locals = { :title => "Repositories - #{APPLICATION_NAME}",
             :list => Model::Project.list_for_user(user_name).collect do |e|
               { 'url'  => "/#{e.user.name}/#{e.name}/",
                 'name' => "#{e.name}" }
             end,
             :logged_in_user => session[:logged_in_user]
           }
  liquid :repo_index, :locals => locals
end

# view: revision index
get '/:user/:project' do |user_name, proj_name|
  locals = { :title => "Revisions - #{APPLICATION_NAME}",
             :list => Model::Revision.list_for_user_proj(user_name, proj_name).collect do |e|
               { 'url'  => "/#{e.project.user.name}/#{e.project.name}/code/#{e.commit_id}/",
                 'name' => "#{e.commit_id}" }
             end,
             :logged_in_user => session[:logged_in_user]
           }
  liquid :revision_index, :locals => locals
end

def serve_gitobj(user_name, proj_name, commit_id, path)
  revision = Model::Revision.lookup(user_name, proj_name, commit_id)
  halt 404, 'Project not found.'  if revision == nil
  path = path.chomp('/')

  gitobj = GitObj.create(revision, path)
  halt 404  if gitobj == nil
  if gitobj.is_tree?
    locals = { :title => "#{revision.project.name}/#{path} - #{APPLICATION_NAME}",
               :project_link_html => make_project_link_html(revision),
               :path_html => make_path_breadcrumb_html(revision, path),
               :list => gitobj.list.collect do |e|
                 { 'url'     => url_for_path(revision, path + '/' + e.name),
                   'name'    => e.name,
                   'is_tree' => e.is_tree }
               end,
               :logged_in_user => session[:logged_in_user]
             }
    liquid :tree, :locals => locals
  else
    locals = { :title => "#{revision.project.name}/#{path} - #{APPLICATION_NAME}",
               :project_link_html => make_project_link_html(revision),
               :path_html => make_path_breadcrumb_html(revision, path),
               :user_name => user_name,
               :proj_name => revision.project.name,
               :revision => revision.commit_id,
               :data => Rack::Utils.escape_html(gitobj.data),
               :path => path,
               :readonly => session[:logged_in_user] ? "false" : "true",
               :logged_in_user => session[:logged_in_user]
             }
    liquid :blob, :locals => locals
  end
end

# view: tree or blob
get '/:user/:project/code/:revision' do |user_name, proj_name, commit_id|
  serve_gitobj(user_name, proj_name, commit_id, '/')
end

# view: tree or blob
get '/:user/:project/code/:revision/*' do |user_name, proj_name, commit_id, path|
  serve_gitobj(user_name, proj_name, commit_id, path)
end

get '/:user/:project/search' do |user_name, proj_name|
  commit_id = request.params['revision']
  path = request.params['path']
  line = request.params['line']
  query = request.params['query']
  halt 404 if commit_id == nil || path == nil || line == nil || query == nil

  revision = Model::Revision.lookup(user_name, proj_name, commit_id)
  halt 404, 'Project not found.'  if revision == nil

  path = path.chomp('/')

  # TODO: prevent injection
  logger.info("executing: cd #{ENV['READHUB_HOME']}/indices/#{revision.project.user.name}/#{revision.project.name}/#{revision.commit_id}/src; global --from-here #{line}:#{path} --result=ctags #{query}")
  list = IO.popen("cd #{ENV['READHUB_HOME']}/indices/#{revision.project.user.name}/#{revision.project.name}/#{revision.commit_id}/src; global --from-here #{line}:#{path} --result=ctags #{query}", 'r') do |io|
    io.readlines.map { |line| line.chomp.split("\t")[1..2] }
  end
  if list.length == 1
    path, line = list[0]
    redirect to("/#{revision.project.user.name}/#{revision.project.name}/code/#{revision.commit_id}/#{path}#L#{line}")

  else
    locals = { :title => "Search result for '#{query}' - #{APPLICATION_NAME}",
               :query => query,
               :list  => list.collect do |path, line|
                 { 'url'     => url_for_path(revision, path + '#L' + line),
                   'name'    => path + ':' + line }
               end,
               :logged_in_user => session[:logged_in_user]
    }
    liquid :search_result, :locals => locals
  end
end
