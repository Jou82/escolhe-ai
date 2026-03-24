# db/migrate/20260323144441_add_status_and_input_movies_to_sessions.rb
class AddStatusAndInputMoviesToSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :sessions, :status, :integer, default: 0, null: false
    add_column :sessions, :input_movies, :jsonb, default: []
    add_column :sessions, :error_message, :string

    add_index :sessions, :status
  end

  def down
    # CORREÇÃO: index_exists? (não index_exist?)
    if index_exists?(:sessions, :status)
      remove_index :sessions, :status
    end

    remove_column :sessions, :status if column_exists?(:sessions, :status)
    # CORREÇÃO: column_exists? (não column_exists?_)
    remove_column :sessions, :input_movies if column_exists?(:sessions, :input_movies)
    remove_column :sessions, :error_message if column_exists?(:sessions, :error_message)
  end
end
