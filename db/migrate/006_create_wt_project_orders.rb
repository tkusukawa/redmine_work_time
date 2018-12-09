class CreateWtProjectOrders < ActiveRecord::Migration[4.2]
  def self.up
    create_table :wt_project_orders do |t|
      t.column :prj, :integer
      t.column :uid, :integer
      t.column :dsp_prj, :integer
      t.column :dsp_pos, :integer
    end
  end

  def self.down
    drop_table :wt_project_orders
  end
end
