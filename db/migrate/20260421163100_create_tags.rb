class CreateTags < ActiveRecord::Migration[8.1]
  def change
    create_table :tags do |t|
      t.citext :name, null: false
      t.citext :slug, null: false
      t.integer :state, default: 0, null: false

      t.timestamps
    end

    add_index :tags, :slug, unique: true
    add_index :tags, :name, unique: true
  end
end
