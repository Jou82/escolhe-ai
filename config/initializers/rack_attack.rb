require "rack/attack"

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
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Limite atingido - Escolhe AI</title>
          <link href="https://cdn.jsdelivr.net/npm/tailwindcss@2.2.19/dist/tailwind.min.css" rel="stylesheet">
          <style>
            body {
              background: radial-gradient(ellipse at 50% 30%, #0f2a4a 0%, #050d1a 70%);
              min-height: 100vh;
            }
          </style>
        </head>
        <body class="flex items-center justify-center min-h-screen text-white font-sans">
          <div class="text-center px-6 max-w-lg">
            <div class="flex items-center justify-center mb-8 text-blue-400">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-10 w-10 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 4v16M17 4v16M3 8h4m10 0h4M3 16h4m10 0h4M4 20h16a1 1 0 001-1V5a1 1 0 00-1-1H4a1 1 0 00-1 1v14a1 1 0 001 1z" />
              </svg>
              <span class="text-xl font-bold tracking-wide">Escolhe AI</span>
            </div>
            <h1 class="text-4xl font-extrabold mb-4">
              Chega de buscas<br>
              <span class="text-blue-400">por hoje.</span>
            </h1>
            <p class="text-gray-400 text-lg mb-10">
              Você já fez 3 buscas hoje.<br>Volte amanhã para mais recomendações!
            </p>
            <a href="/" style="background-color: #2563eb;" class="hover:opacity-90 text-white font-semibold py-3 px-8 rounded-lg transition inline-block">
              Voltar ao início →
            </a>
          </div>
        </body>
      </html>
    HTML
    ]
  ]
end
