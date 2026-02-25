import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bar", "text"]
  static values = {
    phases: Array,
    currentPhase: String,
    phaseStartedAt: String,
    providerProgress: Number // real progress from provider API (0-100), -1 if unavailable
  }

  connect() {
    this.phaseStartedAtTime = new Date(this.phaseStartedAtValue)
    this.totalSeconds = this.phasesValue.reduce((sum, p) => sum + p.seconds, 0)
    this.buildBar()
    requestAnimationFrame(() => {
      if (this.currentFill) this.currentFill.style.transition = "width 1s linear"
      this.tick()
    })
    this.timer = setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    if (this.timer) {
      clearInterval(this.timer)
    }
  }

  currentPhaseIndex() {
    return this.phasesValue.findIndex(p => p.key === this.currentPhaseValue)
  }

  buildBar() {
    if (!this.hasBarTarget) return

    const currentIdx = this.currentPhaseIndex()
    this.barTarget.innerHTML = ""
    this.phaseElements = []

    this.phasesValue.forEach((phase, i) => {
      const pct = (phase.seconds / this.totalSeconds) * 100
      const el = document.createElement("div")
      el.style.flex = `${pct} 0 0%`
      el.style.minWidth = "fit-content"
      el.style.height = "100%"
      el.style.position = "relative"
      el.style.overflow = "hidden"
      el.style.transition = "none"

      // Background for the full segment
      if (i < currentIdx) {
        el.style.backgroundColor = "#198754" // green
      } else {
        el.style.backgroundColor = "#e9ecef" // light gray
      }

      // Animated fill overlay for current phase
      if (i === currentIdx) {
        const fill = document.createElement("div")
        fill.style.position = "absolute"
        fill.style.top = "0"
        fill.style.left = "0"
        fill.style.height = "100%"
        fill.style.width = `${this.computeFillPercent()}%`
        fill.style.backgroundColor = "#0dcaf0"
        fill.style.backgroundImage = "linear-gradient(45deg, rgba(255,255,255,.15) 25%, transparent 25%, transparent 50%, rgba(255,255,255,.15) 50%, rgba(255,255,255,.15) 75%, transparent 75%, transparent)"
        fill.style.backgroundSize = "1rem 1rem"
        fill.style.animation = "progress-bar-stripes 1s linear infinite"
        el.appendChild(fill)
        this.currentFill = fill
      }

      // Label text
      const label = document.createElement("span")
      label.style.position = "relative"
      label.style.zIndex = "1"
      label.style.fontSize = "0.75rem"
      label.style.lineHeight = "24px"
      label.style.padding = "0 6px"
      label.style.whiteSpace = "nowrap"
      label.style.color = i < currentIdx ? "#fff" : (i === currentIdx ? "#000" : "#6c757d")
      label.style.fontWeight = i === currentIdx ? "bold" : "normal"

      const icon = i < currentIdx ? "fa-check" : phase.icon
      label.innerHTML = `<i class="fa ${icon}"></i> ${phase.label}`
      el.appendChild(label)

      // Right border between segments
      if (i < this.phasesValue.length - 1) {
        el.style.borderRight = "2px solid #fff"
      }

      this.barTarget.appendChild(el)
      this.phaseElements.push(el)
    })
  }

  computeFillPercent() {
    const currentIdx = this.currentPhaseIndex()
    if (currentIdx === -1) return 0

    const currentPhase = this.phasesValue[currentIdx]
    const elapsedInPhase = (new Date() - this.phaseStartedAtTime) / 1000

    if (this.providerProgressValue >= 0) {
      return Math.min(100, this.providerProgressValue)
    }
    return Math.min(100, (elapsedInPhase / currentPhase.seconds) * 100)
  }

  tick() {
    const currentIdx = this.currentPhaseIndex()
    if (currentIdx === -1) return

    const currentPhase = this.phasesValue[currentIdx]
    const elapsedInPhase = (new Date() - this.phaseStartedAtTime) / 1000

    if (this.currentFill) {
      this.currentFill.style.width = `${this.computeFillPercent()}%`
    }

    if (this.hasTextTarget) {
      const phaseRemaining = Math.max(0, currentPhase.seconds - elapsedInPhase)
      const futureSeconds = this.phasesValue
        .slice(currentIdx + 1)
        .reduce((sum, p) => sum + p.seconds, 0)
      const totalRemaining = phaseRemaining + futureSeconds

      let phaseText
      if (phaseRemaining > 0) {
        phaseText = `${currentPhase.label} \u2013 approximately ${this.formatTime(phaseRemaining)} remaining`
      } else {
        phaseText = `${currentPhase.label} \u2013 almost done...`
      }

      if (totalRemaining > 0 && futureSeconds > 0) {
        phaseText += ` (total: ~${this.formatTime(totalRemaining)})`
      }

      this.textTarget.textContent = phaseText
    }
  }

  formatTime(seconds) {
    const m = Math.floor(seconds / 60)
    const s = Math.floor(seconds % 60)
    return `${m}:${String(s).padStart(2, "0")}`
  }
}
