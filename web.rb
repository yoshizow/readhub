#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'pp'
require 'test/unit'
require 'digest/sha1'

require 'sinatra'
require 'liquid'
require 'github_api'
require 'dalli'

include Test::Unit::Assertions

# TODO: database
PROJECT_MAP = {
  ['webkit', '20120407'] => ['WebKit', 'webkit', 'e38bcf7cbb5c0988a2eac0b7de8d20367a15ae4f'],
  ['linux', '3.4-rc2'] => ['torvalds', 'linux', '0034102808e0dbbf3a2394b82b1bb40b5778de9e'],
  ['readhub', '20120408'] => ['yoshizow', 'readhub', 'b42a941df221f456877e3879249bd6907057f17a'],
  ['sandbox', '0.0.0'] => ['yoshizow', 'sandbox', 'a332b6e03dd19ef035355acaa8066db14fcbc736']
}

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
  def self.create(project, revision)
    user, repo, commit_id = PROJECT_MAP[[project, revision]]
    if user == nil
      return nil
    else
      return self.new(project, revision, user, repo, commit_id)
    end
  end

  def initialize(project, revision, user, repo, commit_id)
    @project = project
    @revision = revision
    @user = user
    @repo = repo
    @commit_id = commit_id
    @github = CachedGitHubAPI.new(Github.new, settings.cache)  # TODO: inject
  end

  attr_reader :project, :revision, :user, :repo, :commit_id

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
    return '/' + [@project, @revision, path].join('/').gsub(%r!//+!, '/')
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

# actions ----------

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
  return linkify(Rack::Utils.escape_html("#{project.project}-#{project.revision}"), project.url_for_path('/'))
end

get '/' do
  locals = { :list => PROJECT_MAP.keys.collect do |project, revision|
               { 'url'  => "/#{project}/#{revision}/",
                 'name' => "#{project}-#{revision}" }
             end
           }
  liquid :project_index, :locals => locals
end

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
               :user => project.user,
               :repo => project.repo,
               :id => blob.id }
    liquid :blob, :locals => locals
  end
end
