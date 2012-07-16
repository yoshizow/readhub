# -*- Ruby -*-

require 'dm-migrations'

$LOAD_PATH.unshift(File.dirname(__FILE__))
require './model.rb'

namespace :db do
  task :migrate do
    DataMapper.auto_upgrade!
  end

  task :migrate_for_demo do
    project_map = {
      ['webkit', '20120407'] => ['WebKit', 'webkit', 'e38bcf7cbb5c0988a2eac0b7de8d20367a15ae4f'],
      ['linux', '3.4-rc2'] => ['torvalds', 'linux', '0034102808e0dbbf3a2394b82b1bb40b5778de9e'],
      ['readhub', '20120408'] => ['yoshizow', 'readhub', 'b42a941df221f456877e3879249bd6907057f17a'],
      ['sandbox', '0.0.0'] => ['yoshizow', 'sandbox', 'a332b6e03dd19ef035355acaa8066db14fcbc736']
    }
    DataMapper.auto_migrate!
    project_map.each do |k, v|
      name, revision = k
      user, repo, commit_id = v
      project = DB::Project.new(:name => name, :revision => revision)
      project.repo = DB::Repo.new(:user => user, :repo => repo, :commit_id => commit_id)
      project.save
    end
  end
end
