class TmdbService
  BASE_URL = "https://api.themoviedb.org/3"

  def initialize(title, year = nil)
    @title = title
    @year = year
  end

  def call
    movie = search_movie
    return nil unless movie

    providers = fetch_providers(movie["id"])

    {
      tmdb_id: movie["id"],
      title: movie["title"],
      original_title: movie["original_title"],
      overview: movie["overview"],
      poster_url: poster_url(movie["poster_path"]),
      vote_average: movie["vote_average"],
      release_date: movie["release_date"],
      streaming: extract_br_providers(providers, "flatrate"),
      rent: extract_br_providers(providers, "rent"),
      buy: extract_br_providers(providers, "buy")
    }
  end

  def self.enrich_recommendations(recommendations)
    recommendations.map do |rec|
      tmdb_data = new(rec["title"], rec["year"]).call

      if tmdb_data.nil? && rec["original_title"]
        tmdb_data = new(rec["original_title"], rec["year"]).call
      end

      rec.merge("tmdb" => tmdb_data)
    end
  end

  private

  def search_movie
    params = {
      api_key: ENV["TMDB_API_KEY"],
      query: @title,
      language: "pt-BR",
      region: "BR"
    }
    params[:year] = @year if @year

    response = Faraday.get("#{BASE_URL}/search/movie", params)
    results = JSON.parse(response.body)["results"]
    results&.first
  end

  def fetch_providers(movie_id)
    response = Faraday.get(
      "#{BASE_URL}/movie/#{movie_id}/watch/providers",
      { api_key: ENV["TMDB_API_KEY"] }
    )
    JSON.parse(response.body)["results"]
  end

  def extract_br_providers(providers, type)
    br = providers&.dig("BR", type) || []
    br.map do |p|
      {
        name: p["provider_name"],
        logo_url: poster_url(p["logo_path"], "w92")
      }
    end
  end

  def poster_url(path, size = "w500")
    return nil unless path
    "https://image.tmdb.org/t/p/#{size}#{path}"
  end
end
