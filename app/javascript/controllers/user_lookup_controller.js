import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "result", "userId", "submitButton"]
  static values = { url: String }

  connect() {
    this.timeout = null
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  lookup() {
    clearTimeout(this.timeout)
    const input = this.inputTarget.value.trim()

    if (input.length < 2) {
      this.clearResult()
      return
    }

    this.timeout = setTimeout(() => {
      this.performLookup(input)
    }, 300)
  }

  async performLookup(input) {
    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "Content-Type": "application/x-www-form-urlencoded",
          "X-CSRF-Token": csrfToken
        },
        body: `input=${encodeURIComponent(input)}`
      })

      if (response.ok) {
        const text = await response.text()
        if (window.Turbo) {
          window.Turbo.renderStreamMessage(text)
        } else {
          console.error("Turbo not available")
          this.showError("Page not fully loaded, please try again")
        }
      } else {
        this.showError("Failed to lookup user")
      }
    } catch (error) {
      this.showError("Network error occurred")
    }
  }

  selectUser(event) {
    const userId = event.currentTarget.dataset.userId
    const userName = event.currentTarget.dataset.userName

    this.userIdTarget.value = userId
    this.inputTarget.value = userName
    this.resultTarget.innerHTML = ""
    this.enableSubmit()
  }

  clearResult() {
    this.resultTarget.innerHTML = ""
    this.userIdTarget.value = ""
    this.disableSubmit()
  }

  enableSubmit() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false
    }
  }

  disableSubmit() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
    }
  }

  showError(message) {
    this.resultTarget.innerHTML = `
      <div class="alert alert-danger alert-sm">
        ${message}
      </div>
    `
  }

  quickDuration(event) {
    const days = parseInt(event.currentTarget.dataset.days)
    const expiresAt = new Date()
    expiresAt.setDate(expiresAt.getDate() + days)

    // Find the expires_at input within this form
    const form = this.element.querySelector('form')
    const dateInput = form.querySelector('input[name="group_user[expires_at]"]')
    if (dateInput) {
      // Format date for the datepicker
      const formattedDate = this.formatDateForPicker(expiresAt)
      dateInput.value = formattedDate

      // Trigger change event for any other listeners
      dateInput.dispatchEvent(new Event('change'))
    }
  }

  formatDateForPicker(date) {
    const day = String(date.getDate()).padStart(2, '0')
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const year = date.getFullYear()
    const hours = String(date.getHours()).padStart(2, '0')
    const minutes = String(date.getMinutes()).padStart(2, '0')

    return `${day}-${month}-${year} ${hours}:${minutes}`
  }
}
