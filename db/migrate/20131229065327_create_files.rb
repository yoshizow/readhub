class CreateFiles < ActiveRecord::Migration
  def change
    create_table :files do |t|
      t.text :path
      t.references :revision, index: true
    end
  end
end
