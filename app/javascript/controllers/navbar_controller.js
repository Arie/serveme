import { Controller } from "@hotwired/stimulus"

// Toggles the v2 top-nav menu on mobile. Desktop visibility is handled in CSS.
export default class extends Controller {
  static targets = ["menu"]

  toggle() {
    this.menuTarget.classList.toggle("is-open")
  }
}
