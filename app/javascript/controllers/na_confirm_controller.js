import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["checkbox", "form"];

  connect() {
    this.updateFormVisibility();
  }

  toggle() {
    this.updateFormVisibility();
  }

  updateFormVisibility() {
    if (this.hasCheckboxTarget && this.hasFormTarget) {
      if (this.checkboxTarget.checked) {
        this.formTarget.classList.remove("d-none");
      } else {
        this.formTarget.classList.add("d-none");
      }
    }
  }
}
