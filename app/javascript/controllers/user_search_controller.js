import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static values = {
    url: String,
    debounceDelay: { type: Number, default: 300 }
  }

  connect() {
    this.debounceTimer = null
  }

  disconnect() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
  }

  debounceSearch() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }

    this.debounceTimer = setTimeout(() => {
      this.submitForm()
    }, this.debounceDelayValue)
  }

  submitNow() {
    // Submit immediately when group changes
    this.submitForm()
  }

  submitForm() {
    this.element.requestSubmit()
  }
}
