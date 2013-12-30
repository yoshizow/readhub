class CreateProjects < ActiveRecord::Migration
  def change
    create_table :projects do |t|
      t.string :name
      t.timestamps
      t.references :user, index: true
    end
  end
end
