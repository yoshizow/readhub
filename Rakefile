# -*- Ruby -*-

require 'dm-migrations'

require_relative './model.rb'

namespace :db do
  task :migrate do
    DataMapper.auto_upgrade!
  end
end
