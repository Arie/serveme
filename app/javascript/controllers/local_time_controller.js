import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { datetime: String, hour12: { type: Boolean, default: false } }

  connect() {
    const date = new Date(this.datetimeValue)
    this.element.textContent = date.toLocaleTimeString("en-GB", {
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
      hour12: this.hour12Value,
      timeZone: this.#getTimeZone()
    })
  }

  #getTimeZone() {
    const meta = document.querySelector('meta[name="time-zone"]')
    return meta?.content || Intl.DateTimeFormat().resolvedOptions().timeZone
  }
}
