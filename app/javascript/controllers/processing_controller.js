import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["progressText", "statusMessage", "progressCircle"]
  static values = {
    sessionId: String
  }

  connect() {
    this.stepIndex = 0
    this.completed = false
    this.stopped = false
    this.progressInterval = null
    this.pollTimeout = null
    this.circumference = 339.292 // 2 * PI * 54

    this.steps = [
      { progress: 10, message: "Buscando filmes similares..." },
      { progress: 25, message: "Analisando seus gostos..." },
      { progress: 40, message: "Consultando IA..." },
      { progress: 60, message: "Selecionando recomendações..." },
      { progress: 80, message: "Salvando resultados..." },
      { progress: 95, message: "Finalizando..." }
    ]

    this.updateProgressCircle(0)

    setTimeout(() => this.updateProgress(), 1000)
    setTimeout(() => this.checkAndRedirect(), 2000)
  }

  disconnect() {
    this.stopped = true
    if (this.progressInterval) clearTimeout(this.progressInterval)
    if (this.pollTimeout) clearTimeout(this.pollTimeout)
  }

  updateProgressCircle(percent) {
    if (!this.hasProgressCircleTarget) return
    const offset = this.circumference - (percent / 100) * this.circumference
    this.progressCircleTarget.style.strokeDashoffset = offset
  }

  updateProgress() {
    if (this.completed || this.stopped) return

    if (this.stepIndex < this.steps.length) {
      const step = this.steps[this.stepIndex]
      if (this.hasProgressTextTarget) this.progressTextTarget.textContent = step.progress + '%'
      if (this.hasStatusMessageTarget) this.statusMessageTarget.textContent = step.message
      this.updateProgressCircle(step.progress)
      this.stepIndex++

      const delay = Math.random() * 2000 + 2000
      this.progressInterval = setTimeout(() => this.updateProgress(), delay)
    }
  }

  completeProgress() {
    if (this.progressInterval) clearTimeout(this.progressInterval)
    this.completed = true
    if (this.hasProgressTextTarget) this.progressTextTarget.textContent = '100%'
    if (this.hasStatusMessageTarget) this.statusMessageTarget.textContent = 'Pronto! Redirecionando...'
    this.updateProgressCircle(100)
  }

  showFailure(message) {
    if (this.progressInterval) clearTimeout(this.progressInterval)
    this.completed = true
    this.stopped = true
    if (this.hasProgressTextTarget) this.progressTextTarget.textContent = '!'
    if (this.hasStatusMessageTarget) {
      this.statusMessageTarget.textContent = message || "Não foi possível gerar as recomendações. Tente novamente."
    }
  }

  async checkAndRedirect() {
    if (this.stopped || this.completed) return

    try {
      const response = await fetch(`/movies/check_status?id=${this.sessionIdValue}`, {
        headers: { Accept: "application/json" }
      })
      const data = await response.json()

      if (data.status === "completed") {
        this.completeProgress()
        const url = data.url || `/sessions/${this.sessionIdValue}`
        this.pollTimeout = setTimeout(() => { window.location.href = url }, 500)
        return
      }

      if (data.status === "failed") {
        this.showFailure(data.error)
        return
      }

      if (data.status === "not_found") {
        this.showFailure("Sessão não encontrada. Volte e tente de novo.")
        return
      }

      this.pollTimeout = setTimeout(() => this.checkAndRedirect(), 2000)
    } catch (error) {
      console.error('Erro ao verificar status:', error)
      this.pollTimeout = setTimeout(() => this.checkAndRedirect(), 3000)
    }
  }
}
