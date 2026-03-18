class CreateLikes < ActiveRecord::Migration[8.1]
  def change
    create_table :likes do |t|
      t.references :movie, null: false, foreign_key: true
      t.references :session, null: false, foreign_key: true
      t.boolean :suggestion

      t.timestamps
    end
  end
end
