class AddConfirmableToDevise < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :confirmation_token, :string
    add_column :users, :confirmed_at, :datetime
    add_column :users, :confirmation_sent_at, :datetime
    add_column :users, :unconfirmed_email, :string

    add_index :users, :confirmation_token, unique: true

    # Garante que os usuários atuais já nasçam confirmados
    # Usando o helpers do Rails para compatibilidade total
    User.update_all(confirmed_at: Time.current) if User.any?
  end
end
