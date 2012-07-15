# -*- Ruby -*-

require 'dm-migrations'

$LOAD_PATH.unshift(File.dirname(__FILE__))
require './model.rb'

namespace :db do
  task :migrate do
    DataMapper.auto_upgrade!
  end
end
