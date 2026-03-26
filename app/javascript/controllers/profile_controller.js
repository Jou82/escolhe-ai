import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["emailModal", "emailInput", "saveBtn", "nameInput"]

  connect() {
    this.originalEmail = this.emailInputTarget.value
    this.originalName = this.nameInputTarget?.value || ""
    this.updateSaveBtn()
  }

  checkEmail() {
    this.updateSaveBtn()
  }

  checkName() {
    this.updateSaveBtn()
  }

  updateSaveBtn() {
    const emailChanged = this.emailInputTarget.value !== this.originalEmail
    const nameChanged = this.hasNameInputTarget && this.nameInputTarget.value !== this.originalName
    const anyChanged = emailChanged || nameChanged

    this.saveBtnTarget.disabled = !anyChanged
    this.saveBtnTarget.classList.toggle('btn--disabled', !anyChanged)
  }

  openEmailModal() {
    const emailChanged = this.emailInputTarget.value !== this.originalEmail

    if (emailChanged) {
      // email mudou — pede confirmação de senha
      this.emailModalTarget.classList.add('email-modal--open')
    } else {
      // só o nome mudou — submit direto para update_profile_path
      this.saveName()
    }
  }

  async saveName() {
      const csrfToken = document.querySelector('meta[name="csrf-token"]').content

      const response = await fetch("/profile", {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken
        },
        body: JSON.stringify({
          user: {
            display_name: this.nameInputTarget.value
          }
        })
      })

      if (response.ok) {
        this.originalName = this.nameInputTarget.value
        this.updateSaveBtn()
        this.showFlash("Nome atualizado com sucesso!")
      }
    }

  showFlash(message) {
    const flash = document.createElement("div")
    flash.className = "alert alert-success flash-toast"
    flash.textContent = message
    document.body.appendChild(flash)
    setTimeout(() => flash.remove(), 3000)
  }

  closeEmailModal() {
    this.emailModalTarget.classList.remove('email-modal--open')
  }
}
