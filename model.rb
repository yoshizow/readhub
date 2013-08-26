# -*- coding: utf-8 -*-

require 'data_mapper'

LOCAL_DATABASE_URL = 'sqlite3:db.sqlite'

DataMapper::Logger.new($stdout, :debug)

DataMapper.setup(:default, ENV['DATABASE_URL'] || LOCAL_DATABASE_URL)
DataMapper::Model.raise_on_save_failure = true

module DB
  class User
    include DataMapper::Resource

    property :id,       Serial
    property :provider, String, :required => true
    property :name,     String, :required => true

    has n, :projects
  end

  class Project
    include DataMapper::Resource

    property :id,       Serial
    property :name,     String, :required => true
    property :revision, String, :required => true

    has n, :files
    has 1, :repo    # 'repository' can't be used for field name
    belongs_to :user
  end

  class Repo    # Local repository
    include DataMapper::Resource

    property :id,       Serial
    property :path,     String, :length => 1024, :required => true

    belongs_to :project
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
  end
end

DataMapper.finalize
