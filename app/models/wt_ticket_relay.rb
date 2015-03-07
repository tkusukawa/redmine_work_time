class WtTicketRelay < ActiveRecord::Base
  attr_accessible :issue_id, :position, :parent
end
