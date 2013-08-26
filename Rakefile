# -*- Ruby -*-

require 'dm-migrations'

require_relative './model.rb'

namespace :db do
  task :migrate do
    DataMapper.auto_upgrade!
  end

  task :migrate_for_demo do
    project_list = [
      ['readhub', 'b42a941df221f456877e3879249bd6907057f17a', '../readhub.git'],
    ]
    DataMapper.auto_migrate!
    project_list.each do |e|
      proj_name, revision, path = e
      user = DB::User.new(:provider => 'github', :name => 'yoshizow')
      user.save
      project = user.projects.create(:name => proj_name, :revision => revision)
      project.repo = DB::Repo.new(:path => path)
      project.save
    end
  end
end
