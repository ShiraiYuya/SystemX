class CreateAmounts < ActiveRecord::Migration[5.1]
  def change
    create_table :amounts do |t|
	  t.date	:date
	  t.integer	:f_ship, default: 0
	  t.integer	:f_stored, default: 0
	  t.integer	:f_store, default: 0
	  t.integer	:z_ship, default: 0
	  t.integer :z_stored, default: 0
	  t.integer	:z_store, default: 0
	  t.integer :other_ship, default: 0
      t.timestamps
    end
  end
end
