import { Controller } from "@hotwired/stimulus"

const INTERVAL = 15000

export default class extends Controller {
  connect() {
    this.timer = setInterval(() => this.refresh(), INTERVAL)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  refresh() {
    if (document.hidden || this.element.querySelector("details[open]")) return
    if (this.element.src) {
      this.element.reload()
    } else {
      this.element.src = window.location.href
    }
  }
}
