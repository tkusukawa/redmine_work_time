class CreateWtMemberOrders < ActiveRecord::Migration[4.2]
  def self.up
    create_table :wt_member_orders do |t|
      t.column :user_id, :integer
      t.column :position, :integer
    end
  end

  def self.down
    drop_table :wt_member_orders
  end
end
