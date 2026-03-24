// app/javascript/controllers/streaming_search_controller.js

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "dropdown", "tags"]
  static values  = { updateUrl: String }

  // Mapeamento de plataforma → classe CSS da tag
  static TAG_CLASSES = {
    "netflix":       "streaming-tag--netflix",
    "hbo max":       "streaming-tag--hbo-max",
    "disney+":       "streaming-tag--disney",
    "amazon prime":  "streaming-tag--amazon-prime",
    "apple tv+":     "streaming-tag--apple-tv",
    "crunchyroll":   "streaming-tag--crunchyroll",
    "paramount+":    "streaming-tag--paramount",
    "star+":         "streaming-tag--star",
    "globoplay":     "streaming-tag--globoplay",
    "mubi":          "streaming-tag--mubi",
  }

  connect() {
    this.selectedPlatforms = new Set()

    // Carrega plataformas já selecionadas das tags renderizadas pelo ERB
    this.tagsTarget.querySelectorAll(".streaming-tag").forEach((tag) => {
      const platform = tag.dataset.platform
      if (platform) this.selectedPlatforms.add(platform)
    })

    // Fecha dropdown ao clicar fora
    this._outsideClickHandler = (event) => {
      if (!this.element.contains(event.target)) {
        this._hideDropdown()
      }
    }
    document.addEventListener("click", this._outsideClickHandler)
  }

  disconnect() {
    document.removeEventListener("click", this._outsideClickHandler)
  }

  // ── Filtra itens do dropdown conforme digitação ────────────
  filter() {
    const query = this.inputTarget.value.trim().toLowerCase()

    if (query.length === 0) {
      this._hideDropdown()
      return
    }

    this._showDropdown()

    const items = this.dropdownTarget.querySelectorAll(".streaming-card__dropdown-item")
    let visibleCount = 0

    items.forEach((item) => {
      const platform = item.dataset.platform
      const matches = platform.toLowerCase().includes(query) && !this.selectedPlatforms.has(platform)

      item.hidden = !matches
      if (matches) visibleCount++
    })

    if (visibleCount === 0) {
      this._hideDropdown()
    }
  }

  // ── Seleciona uma plataforma do dropdown ───────────────────
  select(event) {
    const platform = event.currentTarget.dataset.platform
    if (this.selectedPlatforms.has(platform)) return

    this.selectedPlatforms.add(platform)
    this._addTag(platform)
    this._hideDropdown()
    this.inputTarget.value = ""
    this._persist()
  }

  // ── Remove uma tag de plataforma ───────────────────────────
  remove(event) {
    const platform = event.currentTarget.dataset.platform

    this.selectedPlatforms.delete(platform)

    const tag = this.tagsTarget.querySelector(`.streaming-tag[data-platform="${platform}"]`)
    if (tag) {
      tag.style.transition = "opacity 0.2s, transform 0.2s"
      tag.style.opacity = "0"
      tag.style.transform = "scale(0.85)"
      setTimeout(() => tag.remove(), 200)
    }

    this._persist()
  }

  // ── Private ────────────────────────────────────────────────

  _addTag(platform) {
    const cssClass = this.constructor.TAG_CLASSES[platform.toLowerCase()] || "streaming-tag--default"

    const tag = document.createElement("span")
    tag.className = `streaming-tag ${cssClass}`
    tag.dataset.platform = platform
    tag.innerHTML = `
      <span class="streaming-tag__name">${platform.toUpperCase()}</span>
      <button type="button" class="streaming-tag__remove"
              data-action="click->streaming-search#remove"
              data-platform="${platform}"
              aria-label="Remover ${platform}">
        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round">
          <path d="M18 6 6 18"/><path d="m6 6 12 12"/>
        </svg>
      </button>
    `
    this.tagsTarget.appendChild(tag)
  }

  _showDropdown() {
    this.dropdownTarget.hidden = false
  }

  _hideDropdown() {
    this.dropdownTarget.hidden = true
  }

  _persist() {
    // Envia PATCH pro update_profile_path com streaming_platforms[]
    const url = this.updateUrlValue
    if (!url) return

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    const platforms = Array.from(this.selectedPlatforms)

    // Monta FormData igual ao form original do profile.html.erb
    const formData = new FormData()
    formData.append("_method", "patch")
    platforms.forEach((p) => formData.append("streaming_platforms[]", p))

    // Se nenhuma plataforma selecionada, envia array vazio
    if (platforms.length === 0) {
      formData.append("streaming_platforms[]", "")
    }

    fetch(url, {
      method: "POST",
      headers: {
        "X-CSRF-Token": csrfToken,
        "Accept": "application/json"
      },
      body: formData
    }).catch((err) => {
      console.error("Erro ao salvar plataformas de streaming:", err)
    })
  }
}
