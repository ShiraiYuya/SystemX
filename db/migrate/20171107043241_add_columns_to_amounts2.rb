class AddColumnsToAmounts2 < ActiveRecord::Migration[5.1]
  def change
	add_column :amounts, :f_morn, :integer, default: 0
    add_column :amounts, :z_morn, :integer, default: 0
    add_column :amounts, :other_morn, :integer, default: 0
	add_column :amounts, :is_def, :boolean, default: false
	add_column :amounts, :is_fin, :boolean, default: false
	remove_column :amounts, :f_pred, :integer
	remove_column :amounts, :z_pred, :integer
	remove_column :amounts, :other_pred, :integer
  end
end
