class CreatePublicKeys < ActiveRecord::Migration
  def change
    create_table :public_keys do |t|
      t.text :public_key
      t.timestamps
      t.references :user, index: true
    end
  end
end
