class CreateWtDailyMemos < ActiveRecord::Migration[4.2]
  def self.up
    create_table :wt_daily_memos do |t|
      t.column :day, :date
      t.column :user_id, :integer
      t.column :created_on, :timestamp
      t.column :updated_on, :timestamp
      t.column :description, :text
    end
  end

  def self.down
    drop_table :wt_daily_memos
  end
end
