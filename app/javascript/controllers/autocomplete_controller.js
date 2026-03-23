import { Controller } from "@hotwired/stimulus"
import TomSelect from "tom-select"

export default class extends Controller {
  connect() {
    const TomSelectConstructor = TomSelect.default || TomSelect;

    this.select = new TomSelectConstructor(this.element, {
      plugins: ['remove_button'],
      valueField: 'title',
      labelField: 'title',
      searchField: 'title',
      maxItems: 3,
      placeholder: "Escolha 3 filmes...",

      // 1. MELHORIA: Limpa o texto da busca assim que você seleciona um filme
      onItemAdd: function() {
        this.setTextboxValue('');
        this.refreshOptions(false);
      },

      // 2. MELHORIA: Limita a quantidade de opções que aparecem na lista
      maxOptions: 5, // Coloquei 5 para dar um pouco de respiro, mas você pode mudar para 3

      // 3. MELHORIA: Evita chamadas excessivas à API (Debounce)
      loadThrottle: 400,

      render: {
        no_results: function(data, escape) {
          return `<div class="no-results">Nenhum filme encontrado para "${escape(data.input)}"</div>`;
        },
        option: function(item, escape) {
          const year = item.year ? ` (${escape(item.year)})` : "";
          return `<div class="py-2 px-3">
                    <div><strong>${escape(item.title)}</strong>${year}</div>
                  </div>`;
        },
        item: function(item, escape) {
          return `<div class="glass-tag">${escape(item.title)}</div>`;
        }
      },

      load: function(query, callback) {
        if (!query.length) return callback();

        fetch(`/movies/search?q=${encodeURIComponent(query)}`)
          .then(response => response.json())
          .then(json => {
            // Se quiser garantir apenas 3 resultados vindo do backend:
            callback(json.slice(0, 3));
          })
          .catch(() => callback());
      }
    });
  }

  disconnect() {
    if (this.select) this.select.destroy();
  }
}
