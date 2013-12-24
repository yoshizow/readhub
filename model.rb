# -*- coding: utf-8 -*-

require 'data_mapper'
require 'dotenv'

DEFAULT_PROVIDER = 'github'

Dotenv.load('/etc/readhub.env')

DataMapper::Logger.new($stdout, :debug)

DataMapper.setup(:default, ENV['DATABASE_URL'])
DataMapper::Model.raise_on_save_failure = true

module DB
  class User
    include DataMapper::Resource

    property :id,       Serial
    property :provider, String, :required => true
    property :name,     String, :required => true

    has n, :public_keys
    has n, :projects
    has n, :comments
  end

  class PublicKey
    include DataMapper::Resource

    property :id,          Serial
    property :public_key,  Text,     :required => true
    property :modified_at, DateTime, :required => true

    belongs_to :user
  end

  class Project
    include DataMapper::Resource

    property :id,       Serial
    property :name,     String, :required => true
    property :revision, String, :required => true
    property :modified_at, DateTime, :required => true

    has n, :files
    belongs_to :user
  end

  class File
    include DataMapper::Resource
    
    property :id,   Serial
    property :path, String, :length => 1024, :required => true

    has n, :comments
    belongs_to :project
  end

  class Comment
    include DataMapper::Resource

    property :id,          Serial
    property :line,        Integer,  :required => true
    property :text,        Text,     :required => true
    property :modified_at, DateTime, :required => true

    belongs_to :file
    belongs_to :user
  end
end

DataMapper.finalize

module DB
  class Project
    def self.lookup(user_name, proj_name, revision)
      user = User.first(:name => user_name, :provider => DEFAULT_PROVIDER)
      if user
        project = user.projects.first(:name => proj_name, :revision => revision)
        return project
      else
        return nil
      end
    end

    def self.list()
      return self.all()
    end

    def self.list_for_user(user_name)
      user = User.first(:name => user_name, :provider => DEFAULT_PROVIDER)
      if user
        return user.projects.all
      else
        return []
      end
    end

    def self.list_for_user_proj(user_name, proj_name)
      user = User.first(:name => user_name, :provider => DEFAULT_PROVIDER)
      if user
        return user.projects.all(:name => proj_name)
      else
        return []
      end
    end

    def get_comments(path)
      file = self.files.first(:path => path)
      if file
        comments = file.comments.all
        return comments
      else
        return []
      end
    end

    def add_comment(logged_in_user, path, line, text)
      file = self.files.first_or_create(:path => path)
      comment = file.comments.first(:user => logged_in_user, :line => line)
      now = Time.now
      if comment
        comment.update(:text => text, :modified_at => now)
      else
        file.comments.create(:user => logged_in_user, :line => line, :text => text, :modified_at => now)
      end
    end

    def delete_comment(logged_in_user, path, line)
      file = self.files.first_or_create(:path => path)
      comments = file.comments.all(:user => logged_in_user, :line => line)
      if comments
        comments.destroy
      end
    end
  end
end

class GitObj
  def self.create(project, path)
    repo_path = "#{ENV['GITOLITE_HOME']}/repositories/#{project.user.name}/#{project.name}.git"
    repo = Rugged::Repository.new(repo_path)
    begin
      commit = repo.lookup(project.revision)
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
