# -*- coding: utf-8 -*-

require 'sinatra'
require 'sinatra/activerecord'
require 'dotenv'

DEFAULT_PROVIDER = 'github'

Dotenv.load('/etc/readhub.env')

set :database, ENV['DATABASE_URL']

module Model

  class User < ActiveRecord::Base
    has_many :public_keys, dependent: :destroy
    has_many :projects, dependent: :destroy
    has_many :comments, dependent: :destroy
  end

  class PublicKey < ActiveRecord::Base
    belongs_to :user
  end

  class Project < ActiveRecord::Base
    has_many :revisions, dependent: :destroy
    belongs_to :user
  end

  class Revision < ActiveRecord::Base
    has_many :files, dependent: :destroy
    belongs_to :project
  end

  class File < ActiveRecord::Base
    has_many :comments, dependent: :destroy
    belongs_to :revision
  end

  class Comment < ActiveRecord::Base
    belongs_to :file
    belongs_to :user
  end

end

module Model
  class Project
    def self.list_for_user(user_name)
      user = User.where(name: user_name, provider: DEFAULT_PROVIDER).first
      if user
        return user.projects.to_a
      else
        return []
      end
    end
  end

  class Revision
    def self.lookup(user_name, proj_name, commit_id)
      user = User.where(name: user_name, provider: DEFAULT_PROVIDER).first
      if user
        project = user.projects.where(name: proj_name).first
        if project
          revision = project.revisions.where(commit_id: commit_id).first
          return revision
        end
      end
      return nil
    end

    def self.list_for_user_proj(user_name, proj_name)
      user = User.where(name: user_name, provider: DEFAULT_PROVIDER).first
      if user
        project = user.projects.where(name: proj_name).first
        if project
          return project.revisions.to_a
        end
      end
      return []
    end

    def get_comments(path)
      file = self.files.where(path: path).first
      if file
        comments = file.comments.to_a
        return comments
      else
        return []
      end
    end

    def add_comment(logged_in_user, path, line, text)
      file = self.files.where(path: path).first_or_create
      comment = file.comments.where(user: logged_in_user, line: line).first_or_initialize
      comment.update(text: text)
    end

    def delete_comment(logged_in_user, path, line)
      file = self.files.where(path: path).first_or_create
      comments = file.comments.where(user: logged_in_user, line: line)
      if comments
        comments.destroy_all
      end
    end
  end
end

class GitObj
  def self.create(revision, path)
    repo_path = "#{ENV['GITOLITE_HOME']}/repositories/#{revision.project.user.name}/#{revision.project.name}.git"
    repo = Rugged::Repository.new(repo_path)
    begin
      commit = repo.lookup(revision.commit_id)
      root = commit.tree
      if path != ''
        info = root.path(path)
        obj = repo.lookup(info[:oid])
      else
        obj = root
      end
      case obj
      when Rugged::Tree
        return Tree.new(obj)
      when Rugged::Blob
        return Blob.new(obj)
      else
        raise 'Unknown object type: ' + obj
      end
    ensure
      repo.close
    end
  end

  class Blob
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

  class Tree
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
end
