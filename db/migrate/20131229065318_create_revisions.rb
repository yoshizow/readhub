class CreateRevisions < ActiveRecord::Migration
  def change
    create_table :revisions do |t|
      t.string :commit_id
      t.timestamps
      t.references :project, index: true
    end
  end
end
