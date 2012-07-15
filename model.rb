# -*- coding: utf-8 -*-

require 'data_mapper'

LOCAL_DATABASE_URL = 'sqlite3:db.sqlite'

DataMapper::Logger.new($stdout, :debug)

DataMapper.setup(:default, ENV['DATABASE_URL'] || LOCAL_DATABASE_URL)

module DB
  class Project
    include DataMapper::Resource

    property :id,       Serial
    property :name,     String
    property :revision, String

    has n, :files
    has 1, :repository
  end

  class Repository    # GitHub repository
    include DataMapper::Resource

    property :id,        Serial
    property :user,      String
    property :repo,      String
    property :commit_id, String

    belongs_to :project
  end

  class File
    include DataMapper::Resource
    
    property :id,   Serial
    property :path, String, :length => 1024

    has n, :comments
    belongs_to :project
  end

  class Comment
    include DataMapper::Resource

    property :id,          Serial
    property :line_number, Integer
    property :text,        Text
    property :modified_at, DateTime

    belongs_to :file
  end
end

DataMapper.finalize
