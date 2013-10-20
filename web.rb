# -*- coding: utf-8 -*-

require 'sinatra'
require 'sinatra/json'
require 'sinatra/flash'
require 'rugged'
require 'liquid'
require 'json'
require 'rest_client'
require 'pp'
#require 'test/unit'

require_relative './model.rb'

#include Test::Unit::Assertions

APPLICATION_NAME = 'ReadHub'

# configurations ----------

$stdout.sync = true

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

# models ----------

DEFAULT_PROVIDER = 'github'

class Project
  def self.list()
    return DB::Project.all()
  end

  def self.create(user_name, proj_name, revision)
    db_user = DB::User.first(:name => user_name, :provider => DEFAULT_PROVIDER)
    if db_user != nil
      db_project = db_user.projects.first(:name => proj_name, :revision => revision)
      if db_project != nil
        return self.new(db_project)
      else
        return nil
      end
    else
      return nil
    end
  end

  def initialize(db_project)
    @db_project = db_project
    @db_repo = @db_project.repo
  end

  def name     ; @db_project.name     ; end
  def revision ; @db_project.revision ; end

  def gitobj_for_path(path)
    repo = Rugged::Repository.new(@db_repo.path)
    begin
      commit = repo.lookup(@db_project.revision)
      root = commit.tree
      if path != ''
        info = root.path(path)
        obj = repo.lookup(info[:oid])
      else
        obj = root
      end
      case obj
      when Rugged::Tree
        return GitTree.new(obj)
      when Rugged::Blob
        return GitBlob.new(obj)
      else
        raise 'Unknown object type: ' + obj
      end
    ensure
      repo.close
    end
  end

  def url_for_path(path)
    return "/#{@db_project.user.name}/#{@db_project.name}/code/#{@db_project.revision}/#{path}".gsub(%r!//+!, '/')
  end

  def get_comments(path)
    db_file = @db_project.files.first(:path => path)
    if db_file != nil
      db_comments = db_file.comments.all
      return db_comments
    else
      return []
    end
  end

  def add_comment(logged_in_user, path, line, text)
    db_file = @db_project.files.first_or_create(:path => path)
    db_comment = db_file.comments.first(:user => logged_in_user, :line => line)
    now = Time.now
    if db_comment != nil
      db_comment.update(:text => text, :modified_at => now)
    else
      db_file.comments.create(:user => logged_in_user, :line => line, :text => text, :modified_at => now)
    end
  end

  def delete_comment(logged_in_user, path, line)
    db_file = @db_project.files.first_or_create(:path => path)
    db_comments = db_file.comments.all(:user => logged_in_user, :line => line)
    if db_comments != nil
      db_comments.destroy
    end
  end
end

class GitBlob
  def initialize(blob)
    @blob = blob
  end

  def data
    @blob.read_raw.data
  end

  def is_tree?
    false
  end
end

class GitTree
  class Entry
    def initialize(entry)
      @name = entry[:name]
      @is_tree = entry[:type] == :tree
    end

    attr_reader :name
    attr_reader :is_tree
  end

  def initialize(tree)
    @list = tree.map { |entry| Entry.new(entry) }
  end

  attr_reader :list

  def is_tree?
    true
  end
end

# helper routines ----------

def linkify(html, url)
  return '<a href="' + url + '">' + html + '</a>'
end

def make_path_breadcrumb_html(project, path)
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

  def make_list(project, path)
    path_components = path.split('/')
    #assert !path_components.include?('')
    list = path_components.each_with_index.collect do |name, idx|
             [name,
              project.url_for_path(path_components[0..idx].join('/'))]
           end
    return list
  end

  return render_html(make_list(project, path))
end

def make_project_link_html(project)
  return linkify(Rack::Utils.escape_html("#{project.name}-#{project.revision}"), project.url_for_path('/'))
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

# API: get comments for specified file
get '/:user/:project/:revision/files/*/comments' do |user_name, proj_name, revision, path|
  project = Project.create(user_name, proj_name, revision)
  halt 404  if project == nil

  blob = project.gitobj_for_path(path)
  halt 404  if blob == nil
  halt 404  if blob.is_tree?
  
  comments = project.get_comments(path)

  json comments.map { |e| { :line => e.line, :text => e.text } }
end

# API: add new comment
post '/:user/:project/:revision/files/*/comments/new' do |user_name, proj_name, revision, path|
  halt 404  if !session[:logged_in_user]
  logged_in_user = DB::User.first(:name => session[:logged_in_user], :provider => DEFAULT_PROVIDER)
  halt 404 if logged_in_user == nil

  project = Project.create(user_name, proj_name, revision)
  halt 404  if project == nil

  params = JSON.parse(request.body.read)
  line = params['line']
  text = params['text']

  begin
    project.add_comment(logged_in_user, path, line, text)
  rescue ForbiddenError
    halt 403
  end

  json 'status' => 'OK'
end

# API: remove comment
delete '/:user/:project/:revision/files/*/comments/:line' do |user_name, proj_name, revision, path, line|
  halt 404  if !session[:logged_in_user]
  logged_in_user = DB::User.first(:name => session[:logged_in_user], :provider => DEFAULT_PROVIDER)
  halt 404 if logged_in_user == nil

  project = Project.create(user_name, proj_name, revision)
  halt 404  if project == nil

  begin
    project.delete_comment(logged_in_user, path, line)
  rescue ForbiddenError
    halt 403
  end

  json 'status' => 'OK'
end

# views ----------

# view: root index
get '/' do
  locals = { :title => "Projects - #{APPLICATION_NAME}",
             :list => Project.list.collect do |e|
               { 'url'  => "/#{e.user.name}/#{e.name}/code/#{e.revision}/",
                 'name' => "#{e.user.name}/#{e.name}/#{e.revision}" }
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
  db_user = DB::User.first_or_create(:name => username, :provider => DEFAULT_PROVIDER)
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
  db_user = DB::User.first(:name => session[:logged_in_user], :provider => DEFAULT_PROVIDER)
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
  db_user = DB::User.first(:name => session[:logged_in_user], :provider => DEFAULT_PROVIDER)
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
    now = Time.now
    if db_public_key != nil
      db_public_key.update(:public_key => key, :modified_at => now)
    else
      db_user.public_keys.create(:public_key => key, :modified_at => now)
    end
    RestClient.post "#{REPOADMIN_SERVER_URL}/certs/#{db_user.name}/new", key, :content_type => "application/octet-stream"
  end

  flash[:notice] = "Saved."
  redirect to('/settings/ssh')
end

# view: tree or blob
get '/:user/:project/code/:revision/*' do |user_name, proj_name, revision, path|
  project = Project.create(user_name, proj_name, revision)
  halt 404, 'Project not found.'  if project == nil
  path = path.chomp('/')

  gitobj = project.gitobj_for_path(path)
  halt 404  if gitobj == nil
  if gitobj.is_tree?
    locals = { :title => "#{project.name}/#{path} - #{APPLICATION_NAME}",
               :project_link_html => make_project_link_html(project),
               :path_html => make_path_breadcrumb_html(project, path),
               :list => gitobj.list.collect do |e|
                 { 'url'     => project.url_for_path(path + '/' + e.name),
                   'name'    => e.name,
                   'is_tree' => e.is_tree }
               end,
               :logged_in_user => session[:logged_in_user]
             }
    liquid :tree, :locals => locals
  else
    locals = { :title => "#{project.name}/#{path} - #{APPLICATION_NAME}",
               :project_link_html => make_project_link_html(project),
               :path_html => make_path_breadcrumb_html(project, path),
               :user_name => user_name,
               :proj_name => project.name,
               :revision => project.revision,
               :data => Rack::Utils.escape_html(gitobj.data),
               :path => path,
               :readonly => session[:logged_in_user] ? "false" : "true",
               :logged_in_user => session[:logged_in_user]
             }
    liquid :blob, :locals => locals
  end
end

get '/:user/:project/search' do |user_name, proj_name|
  revision = request.params['revision']
  path = request.params['path']
  line = request.params['line']
  query = request.params['query']
  halt 404 if revision == nil || path == nil || line == nil || query == nil

  project = Project.create(user_name, proj_name, revision)
  halt 404, 'Project not found.'  if project == nil

  path = path.chomp('/')

  # TODO: prevent injection
  logger.info("executing: cd /home/yoshi/work/readhub/data/#{project.name}; global --from-here #{line}:#{path} --result=ctags #{query}")
  list = IO.popen("cd /home/yoshi/work/readhub/data/#{project.name}; global --from-here #{line}:#{path} --result=ctags #{query}", 'r') do |io|
    io.readlines.map { |line| line.chomp.split("\t")[1..2] }
  end
  if list.length == 1
    path, line = list[0]
    redirect to("/#{user_name}/#{project.name}/code/#{revision}/#{path}#L#{line}")

  else
    locals = { :title => "Search result for '#{query}' - #{APPLICATION_NAME}",
               :query => query,
               :list  => list.collect do |path, line|
                 { 'url'     => project.url_for_path(path + '#L' + line),
                   'name'    => path + ':' + line }
               end,
               :logged_in_user => session[:logged_in_user]
    }
    liquid :search_result, :locals => locals
  end
end
