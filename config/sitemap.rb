SitemapGenerator::Sitemap.default_host = "https://www.escolheai.net"
SitemapGenerator::Sitemap.public_path = 'public/'
SitemapGenerator::Sitemap.sitemaps_path = 'sitemaps/'
SitemapGenerator::Sitemap.compress = true

SitemapGenerator::Sitemap.create do
  # Página inicial
  add '/', changefreq: 'daily', priority: 1.0

  # Página de resultados não é fixa, então não adicionamos URLs dinâmicas
  # Se você quiser que páginas de resultados sejam indexadas,
  # você precisaria adicionar cada sessão, mas geralmente não é recomendado
end
