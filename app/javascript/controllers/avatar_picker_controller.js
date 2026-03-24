import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]

  open() {
    this.modalTarget.classList.add("avatar-modal--open")
  }

  close() {
    this.modalTarget.classList.remove("avatar-modal--open")
  }

  select(e) {
    this.element.querySelectorAll(".avatar-option").forEach(el => el.classList.remove("avatar-option--active"))
    e.currentTarget.classList.add("avatar-option--active")
    this.selectedAvatar = e.currentTarget.dataset.avatar
  }

  async save() {
    if (!this.selectedAvatar) return this.close()

    const response = await fetch("/profile", {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ user: { avatar: this.selectedAvatar } })
    })

    if (response.ok) {
      this.close()
      window.location.reload()
    }
  }
}
