import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["emailModal", "emailInput", "saveBtn"]

  connect() {
    this.originalEmail = this.emailInputTarget.value
    this.saveBtnTarget.disabled = true
    this.saveBtnTarget.classList.add('btn--disabled')
  }

  checkEmail() {
    const changed = this.emailInputTarget.value !== this.originalEmail
    this.saveBtnTarget.disabled = !changed
    this.saveBtnTarget.classList.toggle('btn--disabled', !changed)
  }

  openEmailModal() {
    this.emailModalTarget.classList.add('email-modal--open')
  }

  closeEmailModal() {
    this.emailModalTarget.classList.remove('email-modal--open')
  }
}
