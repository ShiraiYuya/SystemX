class AddColumnsToAmounts < ActiveRecord::Migration[5.1]
  def change
    add_column :amounts, :f_pred, :integer, default: 0
    add_column :amounts, :z_pred, :integer, default: 0
    add_column :amounts, :other_pred, :integer, default: 0
  end
end
