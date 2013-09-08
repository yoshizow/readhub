# -*- Ruby -*-

require 'dm-migrations'

require_relative './model.rb'

namespace :db do
  task :migrate do
    DataMapper.auto_upgrade!
  end

  task :migrate_for_demo do
    project_list = [
      ['yoshizow', 'readhub', 'b42a941df221f456877e3879249bd6907057f17a', '../data/readhub.git'],
      ['yoshizow', 'mruby', '668a0466c551c5a04c1156f4597971f9e183d424', '../data/mruby.git'],
    ]
    DataMapper.auto_migrate!
    project_list.each do |e|
      user_name, proj_name, revision, path = e
      user = DB::User.first_or_new(:provider => 'github', :name => user_name)
      project = user.projects.new(:name => proj_name, :revision => revision)
      project.repo = DB::Repo.new(:path => path)
      user.save
    end
  end
end
