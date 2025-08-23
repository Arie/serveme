import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "search", "group"]
  static values = {
    url: String,
    debounceDelay: { type: Number, default: 300 }
  }

  connect() {
    this.debounceTimer = null
    console.log("User search controller connected")
  }

  disconnect() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
  }

  search() {
    this.debounceSearch()
  }

  groupChange() {
    this.submitForm()
  }

  debounceSearch() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }

    this.debounceTimer = setTimeout(() => {
      this.submitForm()
    }, this.debounceDelayValue)
  }

  submitForm() {
    const formData = new FormData(this.formTarget)
    const params = new URLSearchParams(formData)

    const url = new URL(window.location)
    url.search = params.toString()
    history.replaceState({}, '', url)

    const frame = document.getElementById('users-results')
    if (frame) {
      frame.src = `${this.urlValue}?${params.toString()}`
    }
  }
}
