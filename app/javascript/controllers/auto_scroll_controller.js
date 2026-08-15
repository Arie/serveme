import { Controller } from "@hotwired/stimulus"

// Keeps a scrollable element pinned to the bottom as new content is appended
// (e.g. streamed build output via Turbo Streams). If the user has scrolled up
// to read earlier output, auto-scrolling pauses until they return to the
// bottom, so their reading position isn't yanked away.
export default class extends Controller {
  static values = { threshold: { type: Number, default: 40 } }

  connect() {
    this.scrollToBottom()
    this.observer = new MutationObserver(() => {
      if (this.nearBottom) {
        this.scrollToBottom()
      }
    })
    this.observer.observe(this.element, { childList: true, subtree: true, characterData: true })
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
      this.observer = null
    }
  }

  get nearBottom() {
    const distance = this.element.scrollHeight - this.element.scrollTop - this.element.clientHeight
    return distance <= this.thresholdValue
  }

  scrollToBottom() {
    this.element.scrollTop = this.element.scrollHeight
  }
}
