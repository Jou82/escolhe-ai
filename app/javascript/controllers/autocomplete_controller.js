import { Controller } from "@hotwired/stimulus"

const POSTER_FALLBACK =
  "data:image/svg+xml," +
  encodeURIComponent(
    `<svg xmlns="http://www.w3.org/2000/svg" width="40" height="60" viewBox="0 0 40 60">
      <rect width="40" height="60" fill="#1a1f3a"/>
      <text x="20" y="32" text-anchor="middle" fill="#6b7280" font-size="10" font-family="sans-serif">?</text>
    </svg>`
  )

export default class extends Controller {
  static targets = ["input", "results", "chips", "hidden"]
  static values = {
    max: { type: Number, default: 3 },
    debounce: { type: Number, default: 300 }
  }

  connect() {
    this.selected = []
    this.activeIndex = -1
    this.debounceTimer = null
    this.abortController = null
    this.outsideClick = this.outsideClick.bind(this)
    this.onKeydown = this.onKeydown.bind(this)

    document.addEventListener("click", this.outsideClick)
    this.inputTarget.addEventListener("keydown", this.onKeydown)
    this.syncHiddenFields()
  }

  disconnect() {
    document.removeEventListener("click", this.outsideClick)
    this.inputTarget.removeEventListener("keydown", this.onKeydown)
    clearTimeout(this.debounceTimer)
    this.abortController?.abort()
  }

  signedIn() {
    return document.querySelector('meta[name="user-signed-in"]')?.content === "true"
  }

  openLogin() {
    const loginModal = this.application.getControllerForElementAndIdentifier(
      document.body,
      "login-modal"
    )
    if (loginModal) loginModal.open()
  }

  requireAuth(event) {
    if (this.signedIn()) return
    event?.preventDefault()
    this.inputTarget.blur()
    this.openLogin()
  }

  search() {
    if (!this.signedIn()) {
      this.requireAuth()
      return
    }

    if (this.selected.length >= this.maxValue) {
      this.renderMessage("Já tens 3 produções. Remove uma para pesquisar outra.")
      return
    }

    const query = this.inputTarget.value.trim()
    clearTimeout(this.debounceTimer)

    if (query.length < 2) {
      this.close()
      return
    }

    this.debounceTimer = setTimeout(() => this.fetchResults(query), this.debounceValue)
  }

  async fetchResults(query) {
    this.abortController?.abort()
    this.abortController = new AbortController()

    try {
      const response = await fetch(`/movies/search?q=${encodeURIComponent(query)}`, {
        headers: { Accept: "application/json" },
        signal: this.abortController.signal,
        credentials: "same-origin"
      })

      if (response.status === 401 || response.redirected) {
        this.openLogin()
        this.close()
        return
      }

      if (!response.ok) {
        this.renderMessage("Erro ao buscar. Tenta de novo.")
        return
      }

      const data = await response.json()
      const available = Array.isArray(data)
        ? data.filter((movie) => !this.selected.some((s) => String(s.id) === String(movie.id)))
        : []

      if (available.length === 0) {
        this.renderMessage("Nenhum filme encontrado.")
        return
      }

      this.renderResults(available.slice(0, 8))
    } catch (error) {
      if (error.name === "AbortError") return
      console.error("Autocomplete error:", error)
      this.renderMessage("Erro ao buscar. Tenta de novo.")
    }
  }

  renderResults(movies) {
    this.activeIndex = -1
    this.resultsTarget.innerHTML = ""

    movies.forEach((movie, index) => {
      const li = document.createElement("li")
      li.className = "autocomplete-item"
      li.setAttribute("role", "option")
      li.dataset.index = String(index)
      li.dataset.action = "click->autocomplete#select"
      li.dataset.autocompleteIdParam = movie.id ?? ""
      li.dataset.autocompleteTitleParam = movie.title ?? ""
      li.dataset.autocompleteYearParam = movie.year ?? ""
      li.dataset.autocompleteOriginalTitleParam = movie.original_title ?? ""
      li.dataset.autocompletePosterParam = movie.poster_url ?? ""

      const poster = document.createElement("img")
      poster.className = "movie-poster"
      poster.src = movie.poster_url || POSTER_FALLBACK
      poster.alt = movie.title || ""
      poster.loading = "lazy"
      poster.width = 48
      poster.height = 72

      const meta = document.createElement("div")
      meta.className = "movie-meta"

      const titleRow = document.createElement("div")
      titleRow.className = "movie-title-row"

      const title = document.createElement("span")
      title.className = "movie-title"
      title.textContent = movie.title || "Sem título"

      if (movie.year) {
        const year = document.createElement("span")
        year.className = "movie-year-badge"
        year.textContent = movie.year
        titleRow.append(title, year)
      } else {
        titleRow.append(title)
      }

      const subtitle = document.createElement("span")
      subtitle.className = "movie-subtitle"
      if (movie.original_title && movie.original_title !== movie.title) {
        subtitle.textContent = movie.original_title
      }

      const stats = document.createElement("div")
      stats.className = "movie-stats"
      if (movie.rating > 0) {
        const rating = document.createElement("span")
        rating.className = "movie-rating"
        rating.textContent = `★ ${Number(movie.rating).toFixed(1)}`
        stats.appendChild(rating)
      }
      if (movie.vote_count > 0) {
        const votes = document.createElement("span")
        votes.className = "movie-votes"
        votes.textContent =
          movie.vote_count >= 1000
            ? `${(movie.vote_count / 1000).toFixed(1)}k votos`
            : `${movie.vote_count} votos`
        stats.appendChild(votes)
      }

      const action = document.createElement("span")
      action.className = "movie-select-hint"
      action.textContent = "Selecionar"

      meta.append(titleRow)
      if (subtitle.textContent) meta.append(subtitle)
      if (stats.childNodes.length) meta.append(stats)

      li.append(poster, meta, action)
      this.resultsTarget.appendChild(li)
    })

    this.resultsTarget.classList.add("is-visible")
  }

  renderMessage(text) {
    this.activeIndex = -1
    this.resultsTarget.innerHTML = ""
    const li = document.createElement("li")
    li.className = "autocomplete-message"
    li.textContent = text
    this.resultsTarget.appendChild(li)
    this.resultsTarget.classList.add("is-visible")
  }

  select(event) {
    if (!this.signedIn()) {
      this.openLogin()
      return
    }

    const { id, title, year, poster } = event.params
    if (!title) return

    this.addChip({
      id: id || null,
      title,
      year: year || null,
      poster_url: poster || null
    })
  }

  addChip(movie) {
    if (!movie?.title) return
    if (this.selected.length >= this.maxValue) {
      this.renderMessage("Já tens 3 produções. Remove uma para pesquisar outra.")
      return
    }

    const already = this.selected.some((s) => {
      if (movie.id && s.id) return String(s.id) === String(movie.id)
      return s.title.toLowerCase() === movie.title.toLowerCase()
    })
    if (already) {
      this.inputTarget.value = ""
      this.close()
      return
    }

    this.selected.push({
      id: movie.id || null,
      title: movie.title,
      year: movie.year || null,
      poster_url: movie.poster_url || null
    })

    this.inputTarget.value = ""
    this.renderChips()
    this.syncHiddenFields()
    this.close()
    this.inputTarget.focus()
  }

  removeChip(event) {
    const index = Number(event.params.index)
    if (Number.isNaN(index)) return
    this.selected.splice(index, 1)
    this.renderChips()
    this.syncHiddenFields()
    this.inputTarget.focus()
  }

  renderChips() {
    this.chipsTarget.innerHTML = ""
    this.selected.forEach((movie, index) => {
      const chip = document.createElement("span")
      chip.className = "search-chip"
      chip.dataset.index = String(index)

      if (movie.poster_url) {
        const thumb = document.createElement("img")
        thumb.className = "search-chip-poster"
        thumb.src = movie.poster_url
        thumb.alt = ""
        thumb.width = 22
        thumb.height = 32
        chip.appendChild(thumb)
      }

      const text = document.createElement("span")
      text.className = "search-chip-text"

      const label = document.createElement("span")
      label.className = "search-chip-label"
      label.textContent = movie.title

      text.appendChild(label)
      if (movie.year) {
        const year = document.createElement("span")
        year.className = "search-chip-year"
        year.textContent = movie.year
        text.appendChild(year)
      }

      const remove = document.createElement("button")
      remove.type = "button"
      remove.className = "search-chip-remove"
      remove.setAttribute("aria-label", `Remover ${movie.title}`)
      remove.dataset.action = "click->autocomplete#removeChip"
      remove.dataset.autocompleteIndexParam = String(index)
      remove.textContent = "×"

      chip.append(text, remove)
      this.chipsTarget.appendChild(chip)
    })

    this.inputTarget.placeholder =
      this.selected.length === 0
        ? "Ex.: Interestelar, Cidade de Deus…"
        : this.selected.length >= this.maxValue
          ? "3 produções selecionadas"
          : `Mais ${this.maxValue - this.selected.length}…`
  }

  syncHiddenFields() {
    this.hiddenTarget.innerHTML = ""
    this.selected.forEach((movie) => {
      const titleInput = document.createElement("input")
      titleInput.type = "hidden"
      titleInput.name = "movies[]"
      titleInput.value = movie.title
      this.hiddenTarget.appendChild(titleInput)

      const idInput = document.createElement("input")
      idInput.type = "hidden"
      idInput.name = "tmdb_ids[]"
      idInput.value = movie.id || ""
      this.hiddenTarget.appendChild(idInput)

      const yearInput = document.createElement("input")
      yearInput.type = "hidden"
      yearInput.name = "years[]"
      yearInput.value = movie.year || ""
      this.hiddenTarget.appendChild(yearInput)
    })
  }

  onKeydown(event) {
    if (!this.signedIn() && event.key !== "Tab") {
      if (event.key.length === 1 || event.key === "Backspace") {
        event.preventDefault()
        this.openLogin()
      }
      return
    }

    if (event.key === "Backspace" && !this.inputTarget.value && this.selected.length > 0) {
      this.selected.pop()
      this.renderChips()
      this.syncHiddenFields()
      return
    }

    const items = this.resultsTarget.querySelectorAll(".autocomplete-item")
    if (!this.resultsTarget.classList.contains("is-visible") || items.length === 0) {
      if (event.key === "Escape") this.close()
      return
    }

    if (event.key === "ArrowDown") {
      event.preventDefault()
      this.activeIndex = (this.activeIndex + 1) % items.length
      this.highlight(items)
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this.activeIndex = (this.activeIndex - 1 + items.length) % items.length
      this.highlight(items)
    } else if (event.key === "Enter") {
      if (this.activeIndex >= 0 && items[this.activeIndex]) {
        event.preventDefault()
        items[this.activeIndex].click()
      }
    } else if (event.key === "Escape") {
      event.preventDefault()
      this.close()
    }
  }

  highlight(items) {
    items.forEach((item, index) => {
      item.classList.toggle("is-active", index === this.activeIndex)
    })
    items[this.activeIndex]?.scrollIntoView({ block: "nearest" })
  }

  outsideClick(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  close() {
    this.activeIndex = -1
    this.resultsTarget.innerHTML = ""
    this.resultsTarget.classList.remove("is-visible")
  }
}
