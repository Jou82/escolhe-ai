import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay", "panelLogin", "panelRegister", "panelForgot", "panelResetPassword"]

  connect() {
    this.closeOnEscape = this.closeOnEscape.bind(this)
    this.closeOnOverlayClick = this.closeOnOverlayClick.bind(this)
    const panel = this.element.dataset.autoPanel
    if (panel) {
      this._showPanel(panel)
      this._openOverlay()
    }
  }

  open() {
    this._showPanel("login")
    this._openOverlay()
  }

  openRegister() {
    this._showPanel("register")
    this._openOverlay()
  }

  openForgot() {
    this._showPanel("forgot")
    this._openOverlay()
  }

  close() {
    this.overlayTarget.classList.remove("open")
    document.body.style.overflow = ""
    document.removeEventListener("keydown", this.closeOnEscape)
    this.overlayTarget.removeEventListener("click", this.closeOnOverlayClick)
  }

  switchToRegister(event) {
    event.preventDefault()
    this._showPanel("register")
  }

  switchToLogin(event) {
    event.preventDefault()
    this._showPanel("login")
  }

  switchToForgot(event) {
    event.preventDefault()
    this._showPanel("forgot")
  }

  submitLogin(event) {
    event.preventDefault()
    const form = event.target

    fetch(form.action, {
      method: 'POST',
      body: new FormData(form),
      headers: {
        'Accept': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      }
    })
    .then(res => res.json())
    .then(data => {
      if (data.success) {
        window.location.href = data.redirect
      } else {
        this._showError(data.error, form)
      }
    })
  }

  submitRegister(event) {
    event.preventDefault()
    const form = event.target

    fetch(form.action, {
      method: 'POST',
      body: new FormData(form),
      headers: {
        'Accept': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      }
    })
    .then(res => res.json())
    .then(data => {
      if (data.success) {
        window.location.href = data.redirect
      } else {
        this._showError(data.error, form)
      }
    })
  }

  _showError(message, form) {
    let el = form.querySelector('.modal-error')
    if (!el) {
      el = document.createElement('div')
      el.className = 'modal-error'
      form.prepend(el)
    }
    el.textContent = message
  }

  _showPanel(name) {
    this.panelLoginTarget.hidden         = (name !== "login")
    this.panelRegisterTarget.hidden      = (name !== "register")
    this.panelForgotTarget.hidden        = (name !== "forgot")
    this.panelResetPasswordTarget.hidden = (name !== "resetPassword")
  }

  _openOverlay() {
    this.overlayTarget.classList.add("open")
    document.body.style.overflow = "hidden"
    document.addEventListener("keydown", this.closeOnEscape)
    this.overlayTarget.addEventListener("click", this.closeOnOverlayClick)
  }

  closeOnEscape(event) {
    if (event.key === "Escape") this.close()
  }

  closeOnOverlayClick(event) {
    if (event.target === this.overlayTarget) this.close()
  }
}