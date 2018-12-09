class RemoveMonthFromUserIssueMonth < ActiveRecord::Migration[4.2]
  def self.up
    remove_column :user_issue_months, :month
  end

  def self.down
    add_column :user_issue_months, :month, :string, :default => nil
  end
end
