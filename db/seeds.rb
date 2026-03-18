User.destroy_all

 User.create!([

  { email: "paulo@test.com", password: "123456" },

  { email: "maria@test.com", password: "123456" },

  { email: "joao@test.com", password: "123456" },

  { email: "ana@test.com", password: "123456" },

  { email: "pedro@test.com", password: "123456" }

])

puts "Seed done! #{User.count} users created."
