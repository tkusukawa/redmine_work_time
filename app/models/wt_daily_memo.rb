class WtDailyMemo < ActiveRecord::Base
  attr_accessible :user_id, :day, :created_on, :updated_on, :description
end
