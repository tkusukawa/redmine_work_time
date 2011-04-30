class RemovePrjFromWtProjectOrders < ActiveRecord::Migration
  def self.up
    remove_column :wt_project_orders, :prj
  end

  def self.down
    add_column :wt_project_orders, :prj, :integer, :default => nil
  end
end
