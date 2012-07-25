#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'pp'
require 'test/unit'
require 'digest/sha1'

require 'sinatra'
require 'sinatra/json'
require 'liquid'
require 'github_api'
require 'dalli'
require 'json'

$LOAD_PATH.unshift(File.dirname(__FILE__))
require './model.rb'

include Test::Unit::Assertions

# configurations ----------

$stdout.sync = true

configure :development do
  require 'sinatra/reloader'
end

# handle views/*.liquid.html as Liquid templates
Tilt.prefer Tilt::LiquidTemplate, '.liquid.html'

set :cache, Dalli::Client.new

# models ----------

class Project
  def self.list()
    return DB::Project.all()
  end

  def self.create(project, revision)
    db_project = DB::Project.first(:name => project, :revision => revision)
    if db_project == nil
      return nil
    else
      return self.new(db_project)
    end
  end

  def initialize(db_project)
    @db_project = db_project
    @name = @db_project.name
    @revision = @db_project.revision
    @db_repo = @db_project.repo
    @user = @db_repo.user
    @repo = @db_repo.repo
    @commit_id = @db_repo.commit_id
    @github = CachedGitHubAPI.new(Github.new, settings.cache)  # TODO: inject
  end

  attr_reader :name, :revision, :user, :repo, :commit_id

  def blob_for_path(path)
    tree = @github.get_tree(@user, @repo, @commit_id)
    path_components = path.split('/')
    assert !path_components.include?('')
    if path_components.empty?
      return GitTree.new(tree)
    end
    path_components.each_with_index do |path_component, idx|
      entry = tree['tree'].find { |e| e['path'] == path_component }
      return nil  if entry == nil
      case entry['type']
      when 'tree'
        entry_id = entry['sha']
        tree = @github.get_tree(@user, @repo, entry_id)
        if idx == path_components.size - 1
          return GitTree.new(tree)
        end
      when 'blob'
        if idx == path_components.size - 1
          return GitBlob.new(entry)
        else
          return nil
        end
      else
        raise "Unknown blob type: #{entry.inspect}"
      end
    end
    return nil
  end

  def url_for_path(path)
    return '/' + [@name, @revision, path].join('/').gsub(%r!//+!, '/')
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

  def add_comment(path, line, text)
    db_file = @db_project.files.first_or_create(:path => path)
    db_comment = db_file.comments.first(:line => line)
    now = Time.now
    if db_comment != nil
      db_comment.update(:text => text, :modified_at => now)
    else
      db_file.comments.create(:line => line, :text => text, :modified_at => now)
    end
  end

  def delete_comment(path, line)
    db_file = @db_project.files.first_or_create(:path => path)
    db_comments = db_file.comments.all(:line => line)
    if db_comments != nil
      db_comments.destroy
    end
  end
end

class GitBlob
  def initialize(blob)
    @id = blob['sha']
  end

  attr_reader :id

  def is_tree?
    false
  end
end

class GitTree
  class Entry
    def initialize(entry)
      @name = entry['path']
      @is_tree = entry['type'] == 'tree'
    end

    attr_reader :name
    attr_reader :is_tree
  end

  def initialize(tree)
    @list = tree['tree'].collect { |entry| Entry.new(entry) }
  end

  attr_reader :list

  def is_tree?
    true
  end
end

class CachedGitHubAPI
  def initialize(github, cache)
    @github = github
    @cache = cache
  end

  def get_tree(user, repo, commit_id)
    cache_key = 'GitHub:tree:' + Digest::SHA1.hexdigest([user, repo, commit_id].join(':'))
    result = @cache.get(cache_key)
    if result == nil
      result = @github.git_data.tree(user, repo, commit_id)
      @cache.set(cache_key, result)
    end
    return result
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
    assert !path_components.include?('')
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

# API: get comments for specified file
get '/projects/:project/:revision/files/*/comments' do |project, revision, path|
  project = Project.create(project, revision)
  halt 404  if project == nil

  blob = project.blob_for_path(path)
  halt 404  if blob == nil
  halt 404  if blob.is_tree?
  
  comments = project.get_comments(path)

  json comments.map { |e| { :line => e.line, :text => e.text } }
end

# API: add new comment
post '/projects/:project/:revision/files/*/comments/new' do |project, revision, path|
  project = Project.create(project, revision)
  halt 404  if project == nil

  params = JSON.parse(request.body.read)
  line = params['line']
  text = params['text']

  project.add_comment(path, line, text)

  json 'status' => 'OK'
end

# API: remove comment
delete '/projects/:project/:revision/files/*/comments/:line' do |project, revision, path, line|
  project = Project.create(project, revision)
  halt 404  if project == nil

  project.delete_comment(path, line)

  json 'status' => 'ok'
end

# views ----------

# view: root index
get '/' do
  locals = { :list => Project.list.collect do |e|
               { 'url'  => "/#{e.name}/#{e.revision}/",
                 'name' => "#{e.name}-#{e.revision}" }
             end
           }
  liquid :project_index, :locals => locals
end

# view: tree or blob
get '/:project/:revision/*' do |project, revision, path|
  project = Project.create(project, revision)
  halt 404  if project == nil
  path = path.chomp('/')

  blob = project.blob_for_path(path)
  halt 404  if blob == nil
  if blob.is_tree?
    locals = { :project_link_html => make_project_link_html(project),
               :path_html => make_path_breadcrumb_html(project, path),
               :list => blob.list.collect do |e|
                 { 'url'     => project.url_for_path(path + '/' + e.name),
                   'name'    => e.name,
                   'is_tree' => e.is_tree }
               end
             }
    liquid :tree, :locals => locals
  else
    locals = { :project_link_html => make_project_link_html(project),
               :path_html => make_path_breadcrumb_html(project, path),
               :project => project.name,
               :revision => project.revision,
               :user => project.user,
               :repo => project.repo,
               :id => blob.id,
               :path => path }
    liquid :blob, :locals => locals
  end
end
