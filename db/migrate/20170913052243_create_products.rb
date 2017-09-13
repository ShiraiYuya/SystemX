class CreateProducts < ActiveRecord::Migration[5.1]
  def change
    create_table :products do |t|
      t.integer :company
      t.string :name
      t.integer :storage
      t.integer :timelimit

      t.timestamps
    end
  end
end
