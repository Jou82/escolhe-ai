import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["progressText", "statusMessage", "progressCircle"]
  static values = {
    sessionId: String
  }

  connect() {
    this.stepIndex = 0
    this.completed = false
    this.progressInterval = null
    this.circumference = 339.292 // 2 * PI * 54

    this.steps = [
      { progress: 10, message: "Buscando filmes similares..." },
      { progress: 25, message: "Analisando seus gostos..." },
      { progress: 40, message: "Consultando IA..." },
      { progress: 60, message: "Selecionando recomendações..." },
      { progress: 80, message: "Salvando resultados..." },
      { progress: 95, message: "Finalizando..." }
    ]

    // Inicializa com 0%
    this.updateProgressCircle(0)

    // Inicia as animações
    setTimeout(() => this.updateProgress(), 1000)
    setTimeout(() => this.checkAndRedirect(), 2000)
  }

  disconnect() {
    if (this.progressInterval) {
      clearTimeout(this.progressInterval)
    }
  }

  updateProgressCircle(percent) {
    const offset = this.circumference - (percent / 100) * this.circumference
    this.progressCircleTarget.style.strokeDashoffset = offset
  }

  updateProgress() {
    if (this.completed) return

    if (this.stepIndex < this.steps.length) {
      const step = this.steps[this.stepIndex]
      this.progressTextTarget.textContent = step.progress + '%'
      this.statusMessageTarget.textContent = step.message
      this.updateProgressCircle(step.progress)
      this.stepIndex++

      const delay = Math.random() * 2000 + 2000
      this.progressInterval = setTimeout(() => this.updateProgress(), delay)
    }
  }

  completeProgress() {
    if (this.progressInterval) {
      clearTimeout(this.progressInterval)
    }
    this.completed = true
    this.progressTextTarget.textContent = '100%'
    this.statusMessageTarget.textContent = 'Pronto! Redirecionando...'
    this.updateProgressCircle(100)
  }

  async checkAndRedirect() {
    try {
      const response = await fetch(`/movies/check_status?id=${this.sessionIdValue}`)
      const data = await response.json()

      if (data.status === "completed") {
        this.completeProgress()
        setTimeout(() => {
          window.location.href = `/sessions/${this.sessionIdValue}`
        }, 500)
      } else {
        setTimeout(() => this.checkAndRedirect(), 2000)
      }
    } catch (error) {
      console.error('Erro ao verificar status:', error)
      setTimeout(() => this.checkAndRedirect(), 3000)
    }
  }
}
