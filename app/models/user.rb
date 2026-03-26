class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :omniauthable, :confirmable, omniauth_providers: [:google_oauth2]
  has_many :sessions, dependent: :destroy
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  serialize :streaming_platforms, coder: JSON

  # Callback: Define o avatar antes de criar o registro no banco
  before_validation :set_random_avatar, on: :create

  STREAMING_OPTIONS = [
    "Netflix", "Amazon Prime Video", "Disney Plus", "HBO Max",
    "Globoplay", "Apple TV+", "Paramount+", "MUBI",
    "Telecine", "Crunchyroll", "Claro tv+", "Star+", "Looke"
  ].freeze

  AVATARS = [
  "avatar_1_l9q2gs",
  "avatar_2_fgbof8",
  "avatar_3_m3psu0",
  "avatar_4_xteife",
  "avatar_5_ywu3lw",
  "avatar_6_nmanz1",
  "avatar_7_ctjwgt",
  "avatar_8_uxfd5e",
  "avatar_9_twwfas",
  "avatar_10_pf75ri",
  "avatar_11_wekxdv",
  "avatar_12_d6yrgb",
  "avatar_13_gdjhwo",
  "avatar_14_sbe7tx",
  "avatar_15_ojrgmc",
  "avatar_16_kpsbwm"
  ].freeze

  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.email = auth.info.email
      user.password = Devise.friendly_token[0, 20]
    end
  end


  def avatar_url
    @avatar_url ||= Cloudinary::Utils.cloudinary_url(
      avatar.presence || AVATARS.first,
      width: 200,
      height: 200,
      crop: :fill
    )
  end

  private

  def set_random_avatar
    # Só atribui se o avatar estiver em branco
    self.avatar = AVATARS.sample if avatar.blank?
  end
end
