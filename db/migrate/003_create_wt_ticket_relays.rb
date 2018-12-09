class CreateWtTicketRelays < ActiveRecord::Migration[4.2]
  def self.up
    create_table :wt_ticket_relays do |t|
      t.column :issue_id, :integer
      t.column :position, :integer
      t.column :parent, :integer
    end
  end

  def self.down
    drop_table :wt_ticket_relays
  end
end
