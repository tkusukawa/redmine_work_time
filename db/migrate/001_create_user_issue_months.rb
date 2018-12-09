class CreateUserIssueMonths < ActiveRecord::Migration[4.2]
  def self.up
    create_table :user_issue_months do |t|
      t.column :uid, :integer
      t.column :issue, :integer
      t.column :month, :string
      t.column :odr, :integer
    end
  end

  def self.down
    drop_table :user_issue_months
  end
end
