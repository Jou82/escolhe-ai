import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results"]

  connect() {
    // Fecha o menu se clicar fora dele
    document.addEventListener("click", (e) => {
      if (!this.element.contains(e.target)) this.close()
    })
  }

  search() {
    const value = this.inputTarget.value
    const terms = value.split(',')
    const currentTerm = terms[terms.length - 1].trim() // Pega o que está sendo digitado após a última vírgula

    if (currentTerm.length < 2) {
      this.close()
      return
    }

    // Chama o método 'search' do seu MoviesController
    fetch(`/movies/search?q=${encodeURIComponent(currentTerm)}`)
      .then(response => response.json())
      .then(data => this.renderResults(data))
  }

  renderResults(movies) {
    if (movies.length === 0) {
      this.close()
      return
    }

    const html = movies.slice(0,3).map(movie => `
      <li class="autocomplete-item"
          data-action="click->autocomplete#select"
          data-autocomplete-title-param="${movie.title}">
        <span class="movie-title">${movie.title}</span>
        <span class="movie-year">${movie.year || ''}</span>
      </li>
    `).join('')

    this.resultsTarget.innerHTML = html
    this.resultsTarget.classList.add("is-visible")
  }

  select(event) {
    const selectedTitle = event.params.title
    const terms = this.inputTarget.value.split(',').map(t => t.trim())

    // Substitui o último termo digitado pelo título selecionado
    terms[terms.length - 1] = selectedTitle

    // Junta tudo de novo com vírgula e adiciona uma vírgula no final se houver menos de 3 filmes
    let newValue = terms.join(', ')
    if (terms.length < 3) newValue += ', '

    this.inputTarget.value = newValue
    this.inputTarget.focus()
    this.close()
  }

  close() {
    this.resultsTarget.innerHTML = ""
    this.resultsTarget.classList.remove("is-visible")
  }
}
