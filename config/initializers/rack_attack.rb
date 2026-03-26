require "rack/attack"

# Whitelist localhost em desenvolvimento
Rack::Attack.safelist("allow localhost in development") do |req|
  Rails.env.development? && (req.ip == "127.0.0.1" || req.ip == "::1")
end

Rack::Attack.throttle("movies/ip", limit: 3, period: 1.day) do |req|
  req.ip if req.path == "/movies" && req.post?
end

Rack::Attack.throttled_responder = lambda do |req|
  match_data = req.env["rack.attack.match_data"]
  retry_after = match_data[:period] - (Time.now.to_i % match_data[:period])

  [
    429,
    {
      "Content-Type" => "text/html",
      "Retry-After" => retry_after.to_s
    },
    [<<~HTML
      <html>
        <body style="font-family: sans-serif; text-align: center; padding: 50px;">
          <h2>Limite atingido 🎬</h2>
          <p>Você já fez 3 buscas hoje. Volte amanhã para mais recomendações!</p>
          <a href="/">Voltar ao início</a>
        </body>
      </html>
    HTML
    ]
  ]
end
