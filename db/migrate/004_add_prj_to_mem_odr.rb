class AddPrjToMemOdr < ActiveRecord::Migration
  def self.up
    add_column :wt_member_orders, :prj_id, :integer, :default => nil
  end

  def self.down
    remove_column :wt_member_orders, :prj_id
  end
end
