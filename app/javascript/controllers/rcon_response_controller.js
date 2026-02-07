import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["body", "copyButton"]

  connect() {
    // Delay adding click-outside listener to avoid immediately dismissing
    // from the same click that submitted the form
    requestAnimationFrame(() => {
      this.boundClickOutside = this.clickOutside.bind(this)
      document.addEventListener('click', this.boundClickOutside)
    })
  }

  disconnect() {
    if (this.boundClickOutside) {
      document.removeEventListener('click', this.boundClickOutside)
    }
  }

  close() {
    this.element.remove()
  }

  copy() {
    const text = this.bodyTarget.textContent
    navigator.clipboard.writeText(text).then(() => {
      this.copyButtonTarget.textContent = "\u2713"
      setTimeout(() => {
        this.copyButtonTarget.innerHTML = "&#x2398;"
      }, 1500)
    })
  }

  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.element.remove()
    }
  }
}
