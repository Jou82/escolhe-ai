class AddStatusToSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :sessions, :status, :integer
  end
end
