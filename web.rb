#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'sinatra'
require 'sinatra/json'
require 'rugged'
require 'liquid'
require 'json'
require 'pp'
#require 'test/unit'

require_relative './model.rb'

#include Test::Unit::Assertions

# configurations ----------

$stdout.sync = true

configure :development do
  require 'sinatra/reloader'
  use Rack::CommonLogger
end

# handle views/*.liquid.html as Liquid templates
Tilt.prefer Tilt::LiquidTemplate, '.liquid.html'

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
    return '/' + [@db_project.user.name, @db_project.name, @db_project.revision, path].join('/').gsub(%r!//+!, '/')
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

# APIs ----------

# TEMP
logged_in_user = DB::User.first_or_create(:name => 'yoshizow', :provider => 'github')

# API: get comments for specified file
get '/:user/:project/:revision/files/*/comments' do |user_name, proj_name, revision, path|
  project = Project.create(user_name, proj_name, revision)
  halt 404  if project == nil
  p [:project, project]

  p [:path, path]
  blob = project.gitobj_for_path(path)
  p [:blob, blob]
  halt 404  if blob == nil
  halt 404  if blob.is_tree?
  
  comments = project.get_comments(path)

  json comments.map { |e| { :line => e.line, :text => e.text } }
end

# API: add new comment
post '/:user/:project/:revision/files/*/comments/new' do |user_name, proj_name, revision, path|
  project = Project.create(user_name, proj_name, revision)
  halt 404  if project == nil

  params = JSON.parse(request.body.read)
  line = params['line']
  text = params['text']

  project.add_comment(logged_in_user, path, line, text)

  json 'status' => 'OK'
end

# API: remove comment
delete '/:user/:project/:revision/files/*/comments/:line' do |user_name, proj_name, revision, path, line|
  project = Project.create(user_name, proj_name, revision)
  halt 404  if project == nil

  project.delete_comment(logged_in_user, path, line)

  json 'status' => 'ok'
end

# views ----------

# view: root index
get '/' do
  locals = { :list => Project.list.collect do |e|
               { 'url'  => "/#{e.user.name}/#{e.name}/#{e.revision}/",
                 'name' => "#{e.user.name}/#{e.name}/#{e.revision}" }
             end
           }
  liquid :project_index, :locals => locals
end

# view: tree or blob
get '/:user/:project/:revision/*' do |user_name, proj_name, revision, path|
  project = Project.create(user_name, proj_name, revision)
  halt 404  if project == nil
  path = path.chomp('/')

  gitobj = project.gitobj_for_path(path)
  halt 404  if gitobj == nil
  if gitobj.is_tree?
    locals = { :project_link_html => make_project_link_html(project),
               :path_html => make_path_breadcrumb_html(project, path),
               :list => gitobj.list.collect do |e|
                 { 'url'     => project.url_for_path(path + '/' + e.name),
                   'name'    => e.name,
                   'is_tree' => e.is_tree }
               end
             }
    liquid :tree, :locals => locals
  else
    locals = { :project_link_html => make_project_link_html(project),
               :path_html => make_path_breadcrumb_html(project, path),
               :user_name => user_name,
               :proj_name => project.name,
               :revision => project.revision,
               :data => Rack::Utils.escape_html(gitobj.data),
               :path => path }
    liquid :blob, :locals => locals
  end
end
