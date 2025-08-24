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
    const form = this.element
    const formData = new FormData(form)
    const params = new URLSearchParams(formData)
    
    // Use Turbo to submit the form with replace action
    // This will update the page content and URL properly
    const url = `${this.urlValue}?${params.toString()}`
    Turbo.visit(url, { action: "replace" })
  }
}
