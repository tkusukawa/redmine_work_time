class CreateWtHolidays < ActiveRecord::Migration[4.2]
  def self.up
    create_table :wt_holidays do |t|
      t.column :holiday, :date
      t.column :created_on, :datetime
      t.column :created_by, :integer
      t.column :deleted_on, :datetime
      t.column :deleted_by, :integer
    end
  end

  def self.down
    drop_table :wt_holidays
  end
end
