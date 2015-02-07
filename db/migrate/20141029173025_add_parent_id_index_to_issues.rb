class AddParentIdIndexToIssues < ActiveRecord::Migration
  def self.up
    add_index :issues, :parent_id
  end

  def self.down
    remove_index :issues, :column => :parent_id
  end
end
