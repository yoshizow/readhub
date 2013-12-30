class CreateComments < ActiveRecord::Migration
  def change
    create_table :comments do |t|
      t.integer :line
      t.text :text
      t.timestamps
      t.references :file, index: true
      t.references :user
    end
  end
end
