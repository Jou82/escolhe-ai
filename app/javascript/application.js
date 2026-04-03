// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "@popperjs/core"
import "bootstrap"

// Escuta o evento de carregamento do Turbo para avisar o GTM
document.addEventListener("turbo:load", function(event) {
  window.dataLayer = window.dataLayer || [];
  window.dataLayer.push({
    'event': 'turbo_page_view',
    'page_url': event.detail.url,
    'page_title': document.title
  });
});
