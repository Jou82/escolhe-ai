class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :omniauthable, omniauth_providers: [:google_oauth2]
  has_many :sessions, dependent: :destroy

  serialize :streaming_platforms, coder: JSON

  STREAMING_OPTIONS = [
    "Netflix", "Amazon Prime Video", "Disney Plus", "HBO Max",
    "Globoplay", "Apple TV+", "Paramount+", "MUBI",
    "Telecine", "Crunchyroll", "Claro tv+", "Star+", "Looke"
  ].freeze

  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.email = auth.info.email
      user.password = Devise.friendly_token[0, 20]
    end
  end
end
