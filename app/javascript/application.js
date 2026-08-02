// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import { Turbo } from "@hotwired/turbo-rails"
import "controllers"
import "@popperjs/core"
import "bootstrap"

// Custom Turbo Stream action used by GenerateRecommendationsJob
Turbo.StreamActions.redirect = function () {
  const url = this.getAttribute("url")
  if (url) window.location.href = url
}

// Escuta o evento de carregamento do Turbo para avisar o GTM
document.addEventListener("turbo:load", function(event) {
  window.dataLayer = window.dataLayer || [];
  window.dataLayer.push({
    'event': 'turbo_page_view',
    'page_url': event.detail.url,
    'page_title': document.title
  });
});
