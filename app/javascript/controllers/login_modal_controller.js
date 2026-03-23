import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay", "panelLogin", "panelRegister", "panelForgot"]

  connect() {
    this.closeOnEscape = this.closeOnEscape.bind(this)
    this.closeOnOverlayClick = this.closeOnOverlayClick.bind(this)
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

  _showPanel(name) {
    this.panelLoginTarget.hidden   = (name !== "login")
    this.panelRegisterTarget.hidden = (name !== "register")
    this.panelForgotTarget.hidden  = (name !== "forgot")
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
