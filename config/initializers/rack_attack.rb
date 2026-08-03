# frozen_string_literal: true

class Rack::Attack
  ### Throttles ###

  # General request flood protection (skip Railway healthcheck).
  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path == "/up"
  end

  # Login (Devise sessions#create)
  throttle("logins/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.path == "/users/sign_in" && req.post?
  end

  throttle("logins/email", limit: 8, period: 1.minute) do |req|
    if req.path == "/users/sign_in" && req.post?
      req.params.dig("user", "email").to_s.downcase.presence
    end
  end

  # Password reset requests
  throttle("password_resets/ip", limit: 5, period: 15.minutes) do |req|
    req.ip if req.path == "/users/password" && req.post?
  end

  throttle("password_resets/email", limit: 3, period: 15.minutes) do |req|
    if req.path == "/users/password" && req.post?
      req.params.dig("user", "email").to_s.downcase.presence
    end
  end

  # Registration
  throttle("signups/ip", limit: 5, period: 1.hour) do |req|
    req.ip if req.path == "/users" && req.post?
  end

  # Movie autocomplete (protects TMDB quota)
  throttle("movies_search/ip", limit: 60, period: 1.minute) do |req|
    req.ip if req.path == "/movies/search" && req.get?
  end

  # Recommendation create (extra IP layer; app also has per-user daily quota)
  throttle("movies_create/ip", limit: 10, period: 1.hour) do |req|
    req.ip if req.path == "/movies" && req.post?
  end

  self.throttled_responder = lambda do |_request|
    [
      429,
      { "Content-Type" => "text/plain; charset=utf-8" },
      ["Too many requests. Please try again later.\n"]
    ]
  end
end

# rack-attack's Railtie already inserts the middleware — do not `middleware.use` again.
Rails.application.config.after_initialize do
  Rack::Attack.cache.store = Rails.cache
end
