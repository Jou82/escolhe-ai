# db/seeds.rb

# ============================================
# LIMPEZA NA ORDEM CORRETA (evita foreign key)
# ============================================
puts "Cleaning database in correct order..."
Like.delete_all
Session.delete_all
User.delete_all
puts "Database cleaned!"

# ============================================
# SEU CÓDIGO ORIGINAL (mantido exatamente como está)
# ============================================

# Disable email delivery during seeds (development/docker-compose)
skip_callback = ENV["SKIP_EMAIL"] == "true" || !ENV["SENDGRID_API_KEY"].present?

if skip_callback
  User.skip_callback(:create, :after, :send_devise_notification)
end

User.create!([
  { email: "paulo@test.com", password: "123456" },
  { email: "maria@test.com", password: "123456" },
  { email: "joao@test.com", password: "123456" },
  { email: "ana@test.com", password: "123456" },
  { email: "pedro@test.com", password: "123456" }
])

puts "Seed done! #{User.count} users created."
