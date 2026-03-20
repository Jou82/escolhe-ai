class AddStreamingPlatformsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :streaming_platforms, :text
  end
end
